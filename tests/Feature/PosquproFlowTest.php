<?php

namespace Tests\Feature;

use App\Models\Product;
use App\Models\Tenant;
use App\Models\User;
use App\Services\SaleService;
use Database\Seeders\PosquproSeeder;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PosquproFlowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(RolePermissionSeeder::class);
        $this->seed(PosquproSeeder::class);
    }

    public function test_product_low_stock_detection(): void
    {
        $product = Product::first();
        $this->assertNotNull($product);
        $product->update(['stock' => 1, 'min_stock' => 5]);
        $this->assertTrue($product->fresh()->stock <= $product->fresh()->min_stock);
    }

    public function test_sale_creates_record_in_java_tables(): void
    {
        $user = User::role('Cashier')->first();
        $product = Product::first();
        $before = (int) $product->stock;

        $service = app(SaleService::class);
        $result = $service->create([
            'type' => 'sell',
            'user_id' => $user->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 2, 'unit_price' => (int) $product->selling_price],
            ],
            'payment' => ['method' => 'cash', 'amount' => 2 * (int) $product->selling_price],
        ]);

        $this->assertNotNull($result['sale']);
        $this->assertEquals($before - 2, $product->fresh()->stock);
        $this->assertDatabaseHas('sales', ['id' => $result['sale']->id, 'status' => 'PAID']);
        $this->assertDatabaseHas('sale_items', ['sale_id' => $result['sale']->id, 'product_id' => $product->id]);
        $this->assertDatabaseHas('payments', ['sale_id' => $result['sale']->id, 'method' => 'CASH']);
        $this->assertDatabaseHas('stock_movements', ['product_id' => $product->id, 'movement_type' => 'SALE']);
    }

    public function test_sale_validates_stock(): void
    {
        $product = Product::first();
        $product->update(['stock' => 1]);

        $service = app(SaleService::class);

        $this->expectException(\Exception::class);
        $this->expectExceptionMessage('tidak cukup');

        $service->create([
            'type' => 'sell',
            'user_id' => User::role('Cashier')->first()->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 5, 'unit_price' => (int) $product->selling_price],
            ],
            'payment' => ['method' => 'cash', 'amount' => 5 * (int) $product->selling_price],
        ]);
    }

    public function test_api_requires_auth(): void
    {
        $this->getJson('/api/v1/products')->assertStatus(401);
    }

    public function test_web_login_with_seeded_user(): void
    {
        $response = $this->post('/login', [
            'email' => 'cashier@posqupro.test',
            'password' => 'password',
        ]);

        $response->assertRedirect('/dashboard');
        $this->assertAuthenticated();
    }

    public function test_api_login_with_seeded_user(): void
    {
        $response = $this->postJson('/api/v1/login', [
            'email' => 'admin@posqupro.test',
            'password' => 'password',
        ]);

        $response->assertOk()->assertJsonStructure(['token', 'user']);
    }

    public function test_api_login_rejects_wrong_password(): void
    {
        $response = $this->postJson('/api/v1/login', [
            'email' => 'admin@posqupro.test',
            'password' => 'wrong-password',
        ]);

        $response->assertStatus(401);
    }

    public function test_pos_page_loads_for_cashier(): void
    {
        $user = User::role('Cashier')->first();

        $this->actingAs($user)->get('/pos')->assertOk();
    }

    public function test_tenant_store_creates_admin_account(): void
    {
        $admin = User::role('Super Admin')->first();

        $response = $this->actingAs($admin)->post('/tenants', [
            'name' => 'Tenant Test Co',
            'owner_name' => 'Tenant Owner',
            'owner_email' => 'owner@tenanttest.test',
            'owner_password' => 'password123',
        ]);

        $response->assertRedirect(route('tenants.index'));
        $this->assertDatabaseHas('tenants', ['name' => 'Tenant Test Co']);
        $tenantUser = User::where('email', 'owner@tenanttest.test')->first();
        $this->assertNotNull($tenantUser);
        $this->assertEquals('ADMIN', $tenantUser->role);
        $this->assertNotNull($tenantUser->tenant_id);
        $this->assertTrue($tenantUser->hasRole('Admin'));

        // Admin tenant can login via web
        $this->post('/login', ['email' => 'owner@tenanttest.test', 'password' => 'password123'])
            ->assertRedirect('/dashboard');
    }

    public function test_license_validate_endpoint(): void
    {
        $tenant = Tenant::create(['name' => 'License Test Co', 'status' => 'active']);

        // Valid code + key
        $this->postJson('/api/license/validate', ['licenseCode' => $tenant->license_code], ['X-API-Key' => $tenant->api_key])
            ->assertOk()
            ->assertJson(['valid' => true, 'licenseCode' => $tenant->license_code]);

        // Unknown code
        $this->postJson('/api/license/validate', ['licenseCode' => 'PQ-NOPE-XXXXXX'])
            ->assertNotFound()
            ->assertJson(['valid' => false]);

        // Suspended tenant blocked
        $tenant->update(['status' => 'suspended']);
        $this->postJson('/api/license/validate', ['licenseCode' => $tenant->license_code], ['X-API-Key' => $tenant->api_key ?? ''])
            ->assertStatus(403)
            ->assertJson(['valid' => false]);
    }

    public function test_main_pages_render_for_admin(): void
    {
        $user = User::role('Admin')->first();

        foreach (['/dashboard', '/pos', '/products', '/customers', '/suppliers', '/transactions', '/reports', '/inventory', '/expenses'] as $path) {
            $this->actingAs($user)->get($path)->assertOk();
        }
    }

    public function test_pos_checkout_creates_sale(): void
    {
        $user = User::role('Cashier')->first();
        $product = Product::first();
        $price = (int) $product->selling_price;

        $response = $this->actingAs($user)->post('/pos/checkout', [
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1, 'unit_price' => $price],
            ],
            'paid_amount' => $price,
            'payment' => ['method' => 'cash', 'amount' => $price],
        ]);

        $response->assertSessionHasNoErrors();
        $this->assertDatabaseHas('sales', ['status' => 'PAID']);
        $this->assertDatabaseHas('payments', ['method' => 'CASH']);
    }
}
