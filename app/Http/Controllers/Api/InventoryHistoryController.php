<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\InventoryHistory;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class InventoryHistoryController extends Controller
{
    public function index(Request $request)
    {
        return InventoryHistory::with(['product', 'user'])
            ->when($request->product_id, fn ($q, $v) => $q->where('product_id', $v))
            ->latest()->paginate(15);
    }

    public function store(Request $request)
    {
        $data = $request->validate(['product_id' => ['required', 'exists:products,id'], 'type' => ['required', 'in:in,out,adjustment'], 'quantity' => ['required', 'integer', 'min:1'], 'reason' => ['nullable', 'string']]);

        return DB::transaction(function () use ($data) {
            $product = Product::lockForUpdate()->findOrFail($data['product_id']);
            $before = $product->stock;
            if ($data['type'] === 'in') {
                $product->increment('stock', $data['quantity']);
            } elseif ($data['type'] === 'out') {
                $product->decrement('stock', $data['quantity']);
            } else {
                $product->update(['stock' => $data['quantity']]);
            }
            $product->refresh();

            return InventoryHistory::create([
                'product_id' => $product->id,
                'user_id' => auth()->id(),
                'type' => $data['type'],
                'quantity' => $data['quantity'],
                'stock_before' => $before,
                'stock_after' => $product->stock,
                'reason' => $data['reason'] ?? null,
            ]);
        });
    }

    public function show(InventoryHistory $inventoryHistory)
    {
        return $inventoryHistory->load(['product', 'user']);
    }

    public function destroy(InventoryHistory $inventoryHistory)
    {
        return response()->json(['message' => 'histories cannot be deleted'], 422);
    }
}
