<?php

namespace Tests\Feature;

use App\Models\Product;
use App\Models\User;
use App\Services\TransactionService;
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

    public function test_transaction_creates_inventory_history(): void
    {
        $user = User::role('Cashier')->first();
        $product = Product::first();
        $before = $product->stock;

        $service = app(TransactionService::class);
        $tx = $service->create([
            'type' => 'sell',
            'user_id' => $user->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 2, 'unit_price' => $product->selling_price],
            ],
            'payment' => ['method' => 'cash', 'amount' => 2 * (int) $product->selling_price],
        ]);

        $this->assertEquals($before - 2, $product->fresh()->stock);
        $this->assertDatabaseHas('inventory_histories', ['product_id' => $product->id, 'type' => 'out']);
        $this->assertDatabaseHas('transactions', ['id' => $tx->id]);
    }

    public function test_api_requires_auth(): void
    {
        $this->getJson('/api/v1/products')->assertStatus(401);
    }

    public function test_pos_page_requires_auth(): void
    {
        $this->get('/pos')->assertRedirect('/login');
        $user = User::first();
        $this->actingAs($user)->get('/pos')->assertOk();
    }
}
