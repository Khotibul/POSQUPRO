<?php

namespace App\Services;

use App\Models\Product;
use App\Models\PurchaseOrder;
use App\Models\SupplierInvoice;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class PurchaseOrderService
{
    public function paginate(array $filters = [], int $perPage = 15)
    {
        return PurchaseOrder::with(['supplier', 'user', 'items.product'])
            ->when($filters['status'] ?? null, fn ($q, $v) => $q->where('status', $v))
            ->when($filters['search'] ?? null, fn ($q, $s) => $q->where('po_number', 'like', "%{$s}%"))
            ->latest()
            ->paginate($perPage);
    }

    public function create(array $data): PurchaseOrder
    {
        return DB::transaction(function () use ($data) {
            $items = $data['items'] ?? [];
            $subtotal = 0;
            foreach ($items as $item) {
                $subtotal += $item['quantity'] * $item['unit_cost'] - ($item['discount'] ?? 0);
            }
            $discount = $data['discount'] ?? 0;
            $taxAmount = $data['tax_amount'] ?? 0;
            $total = $subtotal - $discount + $taxAmount;

            $po = PurchaseOrder::create([
                'po_number' => 'PO-'.now()->format('Ymd').'-'.strtoupper(Str::random(6)),
                'supplier_id' => $data['supplier_id'],
                'user_id' => $data['user_id'] ?? auth()->id(),
                'status' => $data['status'] ?? 'draft',
                'expected_date' => $data['expected_date'] ?? null,
                'subtotal' => $subtotal,
                'discount' => $discount,
                'tax_amount' => $taxAmount,
                'total' => $total,
                'notes' => $data['notes'] ?? null,
            ]);

            foreach ($items as $item) {
                $po->items()->create([
                    'product_id' => $item['product_id'],
                    'quantity' => $item['quantity'],
                    'unit_cost' => $item['unit_cost'],
                    'discount' => $item['discount'] ?? 0,
                    'subtotal' => $item['quantity'] * $item['unit_cost'] - ($item['discount'] ?? 0),
                ]);
            }

            return $po->load(['supplier', 'items.product']);
        });
    }

    public function receive(int $id, array $receivedItems): PurchaseOrder
    {
        return DB::transaction(function () use ($id, $receivedItems) {
            $po = PurchaseOrder::with('items.product')->findOrFail($id);
            if (! in_array($po->status, ['ordered', 'partial'])) {
                throw new \Exception('PO cannot be received');
            }

            $allReceived = true;
            foreach ($receivedItems as $received) {
                $item = $po->items()->findOrFail($received['purchase_order_item_id']);
                $item->increment('received_quantity', $received['quantity']);
                $item->refresh();

                // Update product stock
                $product = Product::findOrFail($item->product_id);
                $product->increment('stock', $received['quantity']);
                $product->refresh();

                // Inventory history
                $product->inventoryHistories()->create([
                    'user_id' => auth()->id(),
                    'type' => 'in',
                    'quantity' => $received['quantity'],
                    'stock_before' => $product->stock - $received['quantity'],
                    'stock_after' => $product->stock,
                    'reason' => "PO receive: {$po->po_number}",
                    'reference_type' => PurchaseOrder::class,
                    'reference_id' => $po->id,
                ]);

                if ($item->received_quantity < $item->quantity) {
                    $allReceived = false;
                }
            }

            $po->update(['status' => $allReceived ? 'received' : 'partial']);

            // Create supplier invoice if fully received
            if ($allReceived && $po->invoices()->count() === 0) {
                SupplierInvoice::create([
                    'invoice_number' => 'SI-'.$po->po_number,
                    'supplier_id' => $po->supplier_id,
                    'purchase_order_id' => $po->id,
                    'invoice_date' => now(),
                    'due_date' => now()->addDays(30),
                    'amount' => $po->total,
                    'status' => 'pending',
                ]);
            }

            return $po->fresh(['supplier', 'items.product', 'invoices']);
        });
    }
}
