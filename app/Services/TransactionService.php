<?php

namespace App\Services;

use App\Models\Product;
use App\Models\Transaction;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class TransactionService
{
    /**
     * Mirrors pos-next-js transaction pattern: BEGIN/COMMIT/ROLLBACK via DB::transaction
     * Handles stock deduction/addition + inventory_histories atomically.
     */
    public function create(array $data): Transaction
    {
        return DB::transaction(function () use ($data) {
            $type = $data['type'] ?? 'sell';
            $items = $data['items'] ?? [];

            $subtotal = 0;
            foreach ($items as $item) {
                $subtotal += $item['quantity'] * $item['unit_price'] - ($item['discount'] ?? 0);
            }
            $discount = $data['discount'] ?? 0;
            $taxAmount = $data['tax_amount'] ?? 0;
            $total = $subtotal - $discount + $taxAmount;

            $transaction = Transaction::create([
                'invoice_number' => $data['invoice_number'] ?? 'INV-'.now()->format('Ymd').'-'.strtoupper(Str::random(6)),
                'type' => $type,
                'customer_id' => $data['customer_id'] ?? null,
                'supplier_id' => $data['supplier_id'] ?? null,
                'user_id' => $data['user_id'] ?? auth()->id(),
                'subtotal' => $subtotal,
                'discount' => $discount,
                'tax_amount' => $taxAmount,
                'total' => $total,
                'status' => $data['status'] ?? 'completed',
                'notes' => $data['notes'] ?? null,
            ]);

            foreach ($items as $item) {
                $product = Product::lockForUpdate()->findOrFail($item['product_id']);
                $stockBefore = $product->stock;

                $lineSubtotal = $item['quantity'] * $item['unit_price'] - ($item['discount'] ?? 0);

                $transaction->items()->create([
                    'product_id' => $product->id,
                    'quantity' => $item['quantity'],
                    'unit_price' => $item['unit_price'],
                    'discount' => $item['discount'] ?? 0,
                    'subtotal' => $lineSubtotal,
                ]);

                // Inventory movement (mirrors pos-next-js inventory_histories)
                if ($type === 'sell') {
                    $product->decrement('stock', $item['quantity']);
                    $product->refresh();
                    $transaction->load('items');
                    $product->inventoryHistories()->create([
                        'user_id' => $transaction->user_id,
                        'type' => 'out',
                        'quantity' => $item['quantity'],
                        'stock_before' => $stockBefore,
                        'stock_after' => $product->stock,
                        'reason' => 'Sale '.$transaction->invoice_number,
                        'reference_type' => Transaction::class,
                        'reference_id' => $transaction->id,
                    ]);
                } elseif ($type === 'buy') {
                    $product->increment('stock', $item['quantity']);
                    $product->refresh();
                    $product->inventoryHistories()->create([
                        'user_id' => $transaction->user_id,
                        'type' => 'in',
                        'quantity' => $item['quantity'],
                        'stock_before' => $stockBefore,
                        'stock_after' => $product->stock,
                        'reason' => 'Purchase '.$transaction->invoice_number,
                        'reference_type' => Transaction::class,
                        'reference_id' => $transaction->id,
                    ]);
                }
            }

            // Auto payment if provided
            if (! empty($data['payment'])) {
                $transaction->payments()->create([
                    'amount' => $data['payment']['amount'] ?? $total,
                    'method' => $data['payment']['method'] ?? 'cash',
                    'status' => $data['payment']['status'] ?? 'success',
                    'paid_at' => now(),
                ]);
            }

            return $transaction->load(['items.product', 'customer', 'supplier', 'payments', 'user']);
        });
    }

    public function paginate(array $filters = [], int $perPage = 15)
    {
        return Transaction::with(['customer', 'supplier', 'user', 'items.product', 'payments'])
            ->when($filters['type'] ?? null, fn ($q, $v) => $q->where('type', $v))
            ->when($filters['search'] ?? null, fn ($q, $s) => $q->where('invoice_number', 'like', "%{$s}%"))
            ->latest()
            ->paginate($perPage);
    }
}
