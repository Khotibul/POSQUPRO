<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\TransactionResource;
use App\Models\Transaction;
use App\Services\TransactionService;
use Illuminate\Http\Request;

class TransactionController extends Controller
{
    public function __construct(protected TransactionService $service) {}

    public function index(Request $request)
    {
        return TransactionResource::collection($this->service->paginate($request->only(['type', 'search'])));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'type' => ['required', 'in:buy,sell'],
            'customer_id' => ['nullable', 'exists:customers,id'],
            'supplier_id' => ['nullable', 'exists:suppliers,id'],
            'discount' => ['nullable', 'numeric', 'min:0'],
            'tax_amount' => ['nullable', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.unit_price' => ['required', 'numeric', 'min:0'],
            'items.*.discount' => ['nullable', 'numeric', 'min:0'],
            'payment' => ['nullable', 'array'],
            'payment.method' => ['nullable', 'in:cash,card,qris,transfer'],
            'payment.amount' => ['nullable', 'numeric', 'min:0'],
        ]);

        $transaction = $this->service->create($data);

        return new TransactionResource($transaction);
    }

    public function show(Transaction $transaction)
    {
        return new TransactionResource($transaction->load(['items.product', 'customer', 'supplier', 'payments', 'user']));
    }

    public function destroy(Transaction $transaction)
    {
        $transaction->delete();

        return response()->json(['message' => 'Transaction deleted']);
    }
}
