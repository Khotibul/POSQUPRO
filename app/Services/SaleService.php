<?php

namespace App\Services;

use App\Models\Product;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class SaleService
{
    /**
     * Process POS sale matching Java Desktop flow:
     * 1. Insert into `sales` (Java table)
     * 2. Insert into `sale_items` (Java table)
     * 3. Insert into `payments` with `sale_id` (Java table)
     * 4. Insert into `stock_movements` (Java table)
     * 5. Decrement `products.stock`
     */
    public function create(array $data): array
    {
        return DB::transaction(function () use ($data) {
            $items = $data['items'] ?? [];
            $type = $data['type'] ?? 'sell';

            // Calculate totals
            $subtotal = 0;
            foreach ($items as $item) {
                $subtotal += $item['quantity'] * $item['unit_price'] - ($item['discount'] ?? 0);
            }
            $discount = $data['discount'] ?? 0;
            $tax = $data['tax_amount'] ?? 0;
            $total = $subtotal - $discount + $tax;
            $paidAmount = $data['paid_amount'] ?? ($data['payment']['amount'] ?? $total);
            $changeAmount = max(0, $paidAmount - $total);

            // Default branch/warehouse/shift (Toko Utama / Gudang Utama / current shift)
            $branchId = $data['branch_id'] ?? 1;
            $warehouseId = $data['warehouse_id'] ?? 1;
            $shiftId = $data['shift_id'] ?? $this->getCurrentShiftId($branchId);

            // 1. Insert into `sales` (Java table)
            $saleId = DB::table('sales')->insertGetId([
                'branch_id' => $branchId,
                'warehouse_id' => $warehouseId,
                'shift_id' => $shiftId ?: null,
                'customer_id' => $data['customer_id'] ?? null,
                'invoice_no' => 'INV-'.now()->format('YmdHis').strtoupper(Str::random(3)),
                'cashier_id' => $data['user_id'] ?? auth()->id(),
                'subtotal' => $subtotal,
                'discount' => $discount,
                'tax' => $tax,
                'total' => $total,
                'paid' => $paidAmount,
                'change_amount' => $changeAmount,
                'donation' => $data['donation'] ?? 0,
                'status' => 'PAID',
                'receivable' => $data['receivable'] ?? 0,
                'created_at' => now(),
            ]);

            // 2. Insert into `sale_items` (Java table)
            foreach ($items as $item) {
                $product = Product::lockForUpdate()->findOrFail($item['product_id']);
                $stockBefore = (int) $product->stock;
                $lineSubtotal = $item['quantity'] * $item['unit_price'] - ($item['discount'] ?? 0);

                DB::table('sale_items')->insert([
                    'sale_id' => $saleId,
                    'product_id' => $product->id,
                    'sku' => $product->sku,
                    'product_name' => $product->name,
                    'qty' => $item['quantity'],
                    'price' => $item['unit_price'],
                    'cost' => $product->cost_price ?? $product->cost ?? 0,
                    'discount' => $item['discount'] ?? 0,
                    'tax' => $item['tax'] ?? 0,
                    'subtotal' => $lineSubtotal,
                ]);

                // 3. Decrement stock
                if ($type === 'sell') {
                    if ($stockBefore < $item['quantity']) {
                        throw new \Exception("Stok {$product->name} tidak cukup. Tersedia: {$stockBefore}, diminta: {$item['quantity']}");
                    }
                    $product->decrement('stock', $item['quantity']);
                    $product->refresh();

                    // 4. Insert into `stock_movements` (Java table)
                    DB::table('stock_movements')->insert([
                        'product_id' => $product->id,
                        'warehouse_id' => $warehouseId,
                        'movement_type' => 'SALE',
                        'qty' => $item['quantity'],
                        'reference_no' => DB::table('sales')->where('id', $saleId)->value('invoice_no'),
                        'note' => 'Penjualan via POS',
                        'created_at' => now(),
                    ]);
                } elseif ($type === 'buy') {
                    $product->increment('stock', $item['quantity']);
                    $product->refresh();

                    DB::table('stock_movements')->insert([
                        'product_id' => $product->id,
                        'warehouse_id' => $warehouseId,
                        'movement_type' => 'PURCHASE',
                        'qty' => $item['quantity'],
                        'reference_no' => DB::table('sales')->where('id', $saleId)->value('invoice_no'),
                        'note' => 'Pembelian via POS',
                        'created_at' => now(),
                    ]);
                }
            }

            // 5. Insert into `payments` (Java table) with `sale_id`
            $paymentMethod = strtoupper($data['payment']['method'] ?? 'CASH');
            DB::table('payments')->insert([
                'sale_id' => $saleId,
                'transaction_id' => null,
                'amount' => $paidAmount,
                'method' => $paymentMethod,
                'status' => 'success',
                'paid_at' => now(),
                'reference_no' => $data['payment']['reference_no'] ?? null,
                'created_at' => now(),
            ]);

            // Return sale data
            $sale = DB::table('sales')->where('id', $saleId)->first();
            $saleItems = DB::table('sale_items')->where('sale_id', $saleId)->get();
            $payment = DB::table('payments')->where('sale_id', $saleId)->first();

            return [
                'sale' => $sale,
                'items' => $saleItems,
                'payment' => $payment,
            ];
        });
    }

    private function getCurrentShiftId(int $branchId): int
    {
        try {
            $shift = DB::table('shifts')
                ->where('branch_id', $branchId)
                ->where('status', 'OPEN')
                ->latest()
                ->first();

            if ($shift) {
                return $shift->id;
            }

            // No OPEN shift found — create one
            return DB::table('shifts')->insertGetId([
                'branch_id' => $branchId,
                'user_id' => auth()->id() ?? 1,
                'status' => 'OPEN',
                'opened_at' => now(),
                'created_at' => now(),
            ]);
        } catch (\Exception $e) {
            // Table doesn't exist (SQLite tests) or other error — return 0 to skip FK
            return 0;
        }
    }
}
