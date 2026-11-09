<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ParkedTransactionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'invoice_number' => $this->invoice_number,
            'customer_id' => $this->customer_id,
            'customer' => $this->whenLoaded('customer'),
            'user' => $this->whenLoaded('user'),
            'items' => $this->items,
            'subtotal' => $this->subtotal,
            'discount' => $this->discount,
            'tax_amount' => $this->tax_amount,
            'total' => $this->total,
            'notes' => $this->notes,
            'created_at' => $this->created_at,
        ];
    }
}
