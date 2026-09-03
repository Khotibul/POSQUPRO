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
        return Product::create($data);
    }

    public function update(Product $product, array $data): Product
    {
        $product->update($data);

        return $product->fresh(['category', 'unitQuantity', 'tax', 'supplier']);
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
