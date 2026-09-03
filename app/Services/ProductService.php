<?php

namespace App\Services;

use App\Models\Product;
use App\Repositories\ProductRepository;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class ProductService
{
    public function __construct(protected ProductRepository $repository) {}

    public function paginate(array $filters = [], int $perPage = 15)
    {
        return $this->repository->paginate($filters, $perPage);
    }

    public function find(int $id): ?Product
    {
        return $this->repository->find($id);
    }

    public function create(array $data): Product
    {
        return DB::transaction(function () use ($data) {
            if (empty($data['sku'])) {
                $data['sku'] = 'PRD-'.strtoupper(Str::random(8));
            }
            $product = $this->repository->create($data);

            // Initial stock history
            if (($data['stock'] ?? 0) > 0) {
                $product->inventoryHistories()->create([
                    'user_id' => auth()->id(),
                    'type' => 'in',
                    'quantity' => $data['stock'],
                    'stock_before' => 0,
                    'stock_after' => $data['stock'],
                    'reason' => 'Initial stock',
                ]);
            }

            return $product;
        });
    }

    public function update(Product $product, array $data): Product
    {
        return DB::transaction(function () use ($product, $data) {
            $stockBefore = $product->stock;
            $updated = $this->repository->update($product, $data);

            if (isset($data['stock']) && $data['stock'] != $stockBefore) {
                $diff = $data['stock'] - $stockBefore;
                $updated->inventoryHistories()->create([
                    'user_id' => auth()->id(),
                    'type' => $diff > 0 ? 'in' : ($diff < 0 ? 'out' : 'adjustment'),
                    'quantity' => abs($diff),
                    'stock_before' => $stockBefore,
                    'stock_after' => $data['stock'],
                    'reason' => 'Manual adjustment',
                ]);
            }

            return $updated;
        });
    }

    public function delete(Product $product): bool
    {
        return $this->repository->delete($product);
    }
}
