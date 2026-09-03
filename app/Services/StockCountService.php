<?php

namespace App\Services;

use App\Models\Product;
use App\Models\StockCount;
use App\Models\StockCountItem;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class StockCountService
{
    public function paginate(array $filters = [], int $perPage = 15)
    {
        return StockCount::with(['user', 'approver'])
            ->when($filters['status'] ?? null, fn ($q, $v) => $q->where('status', $v))
            ->latest()
            ->paginate($perPage);
    }

    public function create(array $data): StockCount
    {
        return DB::transaction(function () use ($data) {
            $count = StockCount::create([
                'count_number' => 'SC-'.now()->format('Ymd').'-'.strtoupper(Str::random(6)),
                'user_id' => $data['user_id'] ?? auth()->id(),
                'status' => 'draft',
                'is_blind' => $data['is_blind'] ?? false,
                'notes' => $data['notes'] ?? null,
            ]);

            $products = Product::when($data['product_ids'] ?? null, fn ($q, $ids) => $q->whereIn('id', $ids))->get();
            foreach ($products as $product) {
                StockCountItem::create([
                    'stock_count_id' => $count->id,
                    'product_id' => $product->id,
                    'system_quantity' => $product->stock,
                    'counted_quantity' => null,
                ]);
            }

            return $count->load('items.product');
        });
    }

    public function startCounting(StockCount $count): StockCount
    {
        return $count->update(['status' => 'counting', 'counted_at' => now()]);
    }

    public function recordCount(StockCount $count, array $items): StockCount
    {
        return DB::transaction(function () use ($count, $items) {
            foreach ($items as $itemData) {
                $item = $count->items()->findOrFail($itemData['stock_count_item_id']);
                $item->update(['counted_quantity' => $itemData['counted_quantity'], 'notes' => $itemData['notes'] ?? null]);
            }

            return $count->load('items.product');
        });
    }

    public function approve(StockCount $count): StockCount
    {
        return $count->update(['status' => 'approved', 'approved_by' => auth()->id(), 'approved_at' => now()]);
    }

    public function post(StockCount $count): StockCount
    {
        return DB::transaction(function () use ($count) {
            if ($count->status !== 'approved') {
                throw new \Exception('Stock count must be approved before posting');
            }

            foreach ($count->items as $item) {
                if ($item->counted_quantity !== null && $item->variance !== 0) {
                    $product = Product::lockForUpdate()->findOrFail($item->product_id);
                    $before = $product->stock;
                    $product->update(['stock' => $item->counted_quantity]);
                    $product->refresh();

                    $product->inventoryHistories()->create([
                        'user_id' => auth()->id(),
                        'type' => 'adjustment',
                        'quantity' => abs($item->variance),
                        'stock_before' => $before,
                        'stock_after' => $product->stock,
                        'reason' => "Stock count adjustment: {$count->count_number}",
                        'reference_type' => StockCount::class,
                        'reference_id' => $count->id,
                    ]);

                    ActivityLog::log('stock_count_posted', "Adjusted {$product->name} by {$item->variance}", ['variance' => $item->variance], $count);
                }
            }

            return $count->update(['status' => 'posted', 'posted_at' => now()]);
        });
    }
}
