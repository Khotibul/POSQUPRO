<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PurchaseOrderItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'product' => new ProductResource($this->whenLoaded('product')),
            'quantity' => $this->quantity,
            'received_quantity' => $this->received_quantity,
            'remaining_quantity' => $this->remaining_quantity,
            'unit_cost' => $this->unit_cost,
            'discount' => $this->discount,
            'subtotal' => $this->subtotal,
        ];
    }
}
