<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PurchaseOrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'po_number' => $this->po_number,
            'supplier' => $this->whenLoaded('supplier'),
            'user' => $this->whenLoaded('user'),
            'items' => PurchaseOrderItemResource::collection($this->whenLoaded('items')),
            'invoices' => SupplierInvoiceResource::collection($this->whenLoaded('invoices')),
            'status' => $this->status,
            'expected_date' => $this->expected_date,
            'subtotal' => $this->subtotal,
            'discount' => $this->discount,
            'tax_amount' => $this->tax_amount,
            'total' => $this->total,
            'notes' => $this->notes,
            'created_at' => $this->created_at,
        ];
    }
}
