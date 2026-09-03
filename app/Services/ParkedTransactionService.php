<?php

namespace App\Services;

use App\Models\ParkedTransaction;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class ParkedTransactionService
{
    public function paginate(array $filters = [], int $perPage = 15)
    {
        return ParkedTransaction::with(['customer', 'user'])
            ->when($filters['search'] ?? null, fn ($q, $s) => $q->where('invoice_number', 'like', "%{$s}%"))
            ->latest()
            ->paginate($perPage);
    }

    public function create(array $data): ParkedTransaction
    {
        return DB::transaction(function () use ($data) {
            $invoice = 'PARK-'.now()->format('YmdHis').'-'.strtoupper(Str::random(4));
            $items = $data['items'] ?? [];
            $subtotal = 0;
            foreach ($items as $item) {
                $subtotal += $item['quantity'] * $item['unit_price'] - ($item['discount'] ?? 0);
            }
            $discount = $data['discount'] ?? 0;
            $taxAmount = $data['tax_amount'] ?? 0;
            $total = $subtotal - $discount + $taxAmount;

            return ParkedTransaction::create([
                'invoice_number' => $invoice,
                'customer_id' => $data['customer_id'] ?? null,
                'user_id' => $data['user_id'] ?? auth()->id(),
                'items' => $items,
                'subtotal' => $subtotal,
                'discount' => $discount,
                'tax_amount' => $taxAmount,
                'total' => $total,
                'notes' => $data['notes'] ?? null,
            ]);
        });
    }

    public function restoreToCart(int $id): array
    {
        $parked = ParkedTransaction::findOrFail($id);

        return $parked->items;
    }

    public function delete(ParkedTransaction $parked): bool
    {
        return $parked->delete();
    }
}
