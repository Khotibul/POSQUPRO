<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Supplier;
use App\Models\Tax;
use App\Models\UnitQuantity;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class PosquproSeeder extends Seeder
{
    public function run(): void
    {
        $categories = ['Makanan', 'Minuman', 'Elektronik', 'Pakaian', 'ATK'];
        foreach ($categories as $name) {
            Category::firstOrCreate(['slug' => Str::slug($name)], ['name' => $name]);
        }

        $units = [
            ['name' => 'Piece', 'symbol' => 'pcs'],
            ['name' => 'Kilogram', 'symbol' => 'kg'],
            ['name' => 'Liter', 'symbol' => 'ltr'],
            ['name' => 'Box', 'symbol' => 'box'],
            ['name' => 'Pack', 'symbol' => 'pack'],
        ];
        foreach ($units as $unit) {
            UnitQuantity::firstOrCreate(['symbol' => $unit['symbol']], $unit);
        }

        Tax::firstOrCreate(['name' => 'PPN 11%'], ['rate' => 11.00]);
        Tax::firstOrCreate(['name' => 'PPN 0%'], ['rate' => 0.00]);

        // Java's suppliers/customers require 'code' field
        $supplierCode = 'SUP-' . strtoupper(Str::random(6));
        $customerCode = 'CUST-' . strtoupper(Str::random(6));
        // Use DB directly to handle Java's code requirement
        $supplierData = ['name' => 'PT Sumber Makmur', 'email' => 'supplier@example.com', 'phone' => '08123456789', 'address' => 'Jl. Industri No. 1'];
        $customerData = ['name' => 'Pelanggan Umum', 'phone' => '0811111111', 'address' => 'Walk-in'];
        // Try with code, fallback if code column doesn't exist (for fresh Laravel DB)
        try {
            Supplier::firstOrCreate(['name' => 'PT Sumber Makmur'], array_merge($supplierData, ['code' => $supplierCode]));
        } catch (\Exception $e) {
            // If code column missing, try without
            if (str_contains($e->getMessage(), 'code')) {
                \Illuminate\Support\Facades\DB::table('suppliers')->updateOrInsert(['name' => 'PT Sumber Makmur'], array_merge($supplierData, ['code' => $supplierCode, 'created_at' => now(), 'updated_at' => now()]));
            } else {
                throw $e;
            }
        }
        try {
            Customer::firstOrCreate(['name' => 'Pelanggan Umum'], array_merge($customerData, ['code' => $customerCode]));
        } catch (\Exception $e) {
            if (str_contains($e->getMessage(), 'code')) {
                \Illuminate\Support\Facades\DB::table('customers')->updateOrInsert(['name' => 'Pelanggan Umum'], array_merge($customerData, ['code' => $customerCode, 'created_at' => now(), 'updated_at' => now()]));
            } else {
                throw $e;
            }
        }

        $category = Category::first();
        $unit = UnitQuantity::first();
        $tax = Tax::first();
        $supplier = Supplier::where('name', 'PT Sumber Makmur')->first() ?? Supplier::first();
        if ($category && $unit && $tax && $supplier && Product::count() === 0) {
            $products = [
                ['name' => 'Kopi Arabica 1kg', 'sku' => 'PRD-001', 'selling_price' => 85000, 'cost_price' => 60000, 'stock' => 100],
                ['name' => 'Gula Pasir 1kg', 'sku' => 'PRD-002', 'selling_price' => 15000, 'cost_price' => 12000, 'stock' => 200],
                ['name' => 'Minyak Goreng 1L', 'sku' => 'PRD-003', 'selling_price' => 18000, 'cost_price' => 15000, 'stock' => 150],
                ['name' => 'Teh Celup Box', 'sku' => 'PRD-004', 'selling_price' => 12000, 'cost_price' => 8000, 'stock' => 80],
            ];
            foreach ($products as $p) {
                // Create with both Laravel and Java columns
                $data = array_merge($p, [
                    'barcode' => $p['sku'],
                    'category_id' => $category->id,
                    'unit_quantity_id' => $unit->id,
                    'tax_id' => $tax->id,
                    'supplier_id' => $supplier->id,
                    'type' => 'finished_goods',
                    'min_stock' => 10,
                    // Java required columns
                    'price' => $p['selling_price'],
                    'cost' => $p['cost_price'],
                    'category' => $category->name,
                    'active' => 1,
                    'is_active' => 1,
                ]);
                // Set unit_id for Java if exists
                if (\Illuminate\Support\Facades\Schema::hasColumn('products', 'unit_id')) {
                    $data['unit_id'] = $unit->id;
                }
                try {
                    Product::create($data);
                } catch (\Exception $e) {
                    // Fallback via DB with minimal Java fields
                    \Illuminate\Support\Facades\DB::table('products')->insert(array_merge([
                        'sku' => $p['sku'],
                        'barcode' => $p['sku'],
                        'name' => $p['name'],
                        'price' => $p['selling_price'],
                        'cost' => $p['cost_price'],
                        'stock' => $p['stock'],
                        'min_stock' => 10,
                        'active' => 1,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ], []));
                }
            }
        }
    }
}
