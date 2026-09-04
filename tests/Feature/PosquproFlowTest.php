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
}
