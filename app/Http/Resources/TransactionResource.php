<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TransactionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'invoice_number' => $this->invoice_number,
            'type' => $this->type,
            'customer' => $this->whenLoaded('customer'),
            'supplier' => $this->whenLoaded('supplier'),
            'user' => $this->whenLoaded('user'),
            'items' => TransactionItemResource::collection($this->whenLoaded('items')),
            'payments' => $this->whenLoaded('payments'),
            'subtotal' => $this->subtotal,
            'discount' => $this->discount,
            'tax_amount' => $this->tax_amount,
            'total' => $this->total,
            'status' => $this->status,
            'notes' => $this->notes,
            'created_at' => $this->created_at,
        ];
    }
}
