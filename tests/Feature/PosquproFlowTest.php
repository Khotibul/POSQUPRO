<?php

namespace Tests\Feature;

use App\Models\Product;
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
