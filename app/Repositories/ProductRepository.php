<?php

namespace App\Repositories;

use App\Models\Product;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Collection;

class ProductRepository
{
    public function paginate(array $filters = [], int $perPage = 15): LengthAwarePaginator
    {
        return Product::with(['category', 'unitQuantity', 'tax', 'supplier'])
            ->when($filters['search'] ?? null, fn ($q, $s) => $q->where(fn ($qq) => $qq->where('name', 'like', "%{$s}%")->orWhere('sku', 'like', "%{$s}%")->orWhere('barcode', 'like', "%{$s}%")))
            ->when($filters['category_id'] ?? null, fn ($q, $v) => $q->where('category_id', $v))
            ->when($filters['type'] ?? null, fn ($q, $v) => $q->where('type', $v))
            ->latest()
            ->paginate($perPage);
    }

    public function find(int $id): ?Product
    {
        return Product::with(['category', 'unitQuantity', 'tax', 'supplier', 'inventoryHistories'])->find($id);
    }

    public function create(array $data): Product
    {
        return Product::create(self::withPriceAliases($data));
    }

    public function update(Product $product, array $data): Product
    {
        $product->update(self::withPriceAliases($data));

        return $product->fresh(['category', 'unitQuantity', 'tax', 'supplier']);
    }

    /**
     * Keep Java/desktop-compatible aliases in sync: price <-> selling_price,
     * cost <-> cost_price. Java desktop reads `price`/`cost` directly while
     * Laravel writes `selling_price`/`cost_price`.
     *
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private static function withPriceAliases(array $data): array
    {
        if (array_key_exists('selling_price', $data) && ! array_key_exists('price', $data)) {
            $data['price'] = $data['selling_price'];
        } elseif (array_key_exists('price', $data) && ! array_key_exists('selling_price', $data)) {
            $data['selling_price'] = $data['price'];
        }

        if (array_key_exists('cost_price', $data) && ! array_key_exists('cost', $data)) {
            $data['cost'] = $data['cost_price'];
        } elseif (array_key_exists('cost', $data) && ! array_key_exists('cost_price', $data)) {
            $data['cost_price'] = $data['cost'];
        }

        return $data;
    }

    public function delete(Product $product): bool
    {
        return $product->delete();
    }

    public function lowStock(): Collection
    {
        return Product::whereColumn('stock', '<=', 'min_stock')->get();
    }
}
