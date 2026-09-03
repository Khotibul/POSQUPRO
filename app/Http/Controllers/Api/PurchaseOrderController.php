<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\PurchaseOrderResource;
use App\Models\PurchaseOrder;
use App\Services\PurchaseOrderService;
use Illuminate\Http\Request;

class PurchaseOrderController extends Controller
{
    public function __construct(protected PurchaseOrderService $service) {}

    public function index(Request $request)
    {
        return PurchaseOrderResource::collection($this->service->paginate($request->only(['status', 'search'])));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'supplier_id' => ['required', 'exists:suppliers,id'],
            'expected_date' => ['nullable', 'date'],
            'status' => ['sometimes', 'in:draft,ordered,partial,received,cancelled'],
            'notes' => ['nullable', 'string'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.unit_cost' => ['required', 'numeric', 'min:0'],
            'items.*.discount' => ['nullable', 'numeric', 'min:0'],
        ]);
        $data['user_id'] = auth()->id();

        return new PurchaseOrderResource($this->service->create($data));
    }

    public function show(PurchaseOrder $purchaseOrder)
    {
        return new PurchaseOrderResource($purchaseOrder->load(['supplier', 'user', 'items.product', 'invoices']));
    }

    public function receive(Request $request, PurchaseOrder $purchaseOrder)
    {
        $data = $request->validate([
            'items' => ['required', 'array', 'min:1'],
            'items.*.purchase_order_item_id' => ['required', 'exists:purchase_order_items,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
        ]);

        return new PurchaseOrderResource($this->service->receive($purchaseOrder->id, $data['items']));
    }

    public function destroy(PurchaseOrder $purchaseOrder)
    {
        if (! in_array($purchaseOrder->status, ['draft', 'cancelled'])) {
            return response()->json(['message' => 'Cannot delete non-draft PO'], 422);
        }
        $purchaseOrder->delete();

        return response()->json(['message' => 'deleted']);
    }
}
