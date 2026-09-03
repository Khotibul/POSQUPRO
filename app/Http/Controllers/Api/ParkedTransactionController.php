<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ParkedTransactionResource;
use App\Models\ParkedTransaction;
use App\Services\ParkedTransactionService;
use Illuminate\Http\Request;

class ParkedTransactionController extends Controller
{
    public function __construct(protected ParkedTransactionService $service) {}

    public function index(Request $request)
    {
        return ParkedTransactionResource::collection($this->service->paginate($request->only(['search'])));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'customer_id' => ['nullable', 'exists:customers,id'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.unit_price' => ['required', 'numeric'],
            'items.*.discount' => ['nullable', 'numeric'],
            'discount' => ['nullable', 'numeric'],
            'tax_amount' => ['nullable', 'numeric'],
            'notes' => ['nullable', 'string'],
        ]);
        $data['user_id'] = auth()->id();

        return new ParkedTransactionResource($this->service->create($data));
    }

    public function show($id)
    {
        $parked = ParkedTransaction::with(['customer', 'user'])->findOrFail($id);

        return new ParkedTransactionResource($parked);
    }

    public function restore($id)
    {
        $items = $this->service->restoreToCart($id);

        return response()->json(['items' => $items]);
    }

    public function destroy($id)
    {
        $parked = ParkedTransaction::findOrFail($id);
        $this->service->delete($parked);

        return response()->json(['message' => 'deleted']);
    }
}
