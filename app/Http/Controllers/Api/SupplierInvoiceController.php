<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\SupplierInvoiceResource;
use App\Models\SupplierInvoice;
use Illuminate\Http\Request;

class SupplierInvoiceController extends Controller
{
    public function index(Request $request)
    {
        return SupplierInvoiceResource::collection(SupplierInvoice::with(['supplier', 'purchaseOrder'])
            ->when($request->status, fn ($q, $v) => $q->where('status', $v))
            ->latest()->paginate(15));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'supplier_id' => ['required', 'exists:suppliers,id'],
            'purchase_order_id' => ['nullable', 'exists:purchase_orders,id'],
            'invoice_number' => ['required', 'string', 'unique:supplier_invoices'],
            'invoice_date' => ['required', 'date'],
            'due_date' => ['nullable', 'date'],
            'amount' => ['required', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
        ]);

        return new SupplierInvoiceResource(SupplierInvoice::create($data));
    }

    public function show(SupplierInvoice $supplierInvoice)
    {
        return new SupplierInvoiceResource($supplierInvoice->load(['supplier', 'purchaseOrder']));
    }

    public function update(Request $request, SupplierInvoice $supplierInvoice)
    {
        $data = $request->validate([
            'amount' => ['sometimes', 'numeric', 'min:0'],
            'due_date' => ['nullable', 'date'],
            'status' => ['sometimes', 'in:pending,partial,paid,overdue,cancelled'],
            'notes' => ['nullable', 'string'],
        ]);
        $supplierInvoice->update($data);

        return new SupplierInvoiceResource($supplierInvoice);
    }

    public function destroy(SupplierInvoice $supplierInvoice)
    {
        $supplierInvoice->delete();

        return response()->json(['message' => 'deleted']);
    }
}
