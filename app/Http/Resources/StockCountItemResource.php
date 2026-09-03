<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class StockCountItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'product' => new ProductResource($this->whenLoaded('product')),
            'system_quantity' => $this->system_quantity,
            'counted_quantity' => $this->counted_quantity,
            'variance' => $this->variance,
            'notes' => $this->notes,
        ];
    }
}
