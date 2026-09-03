<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'sku' => $this->sku,
            'barcode' => $this->barcode,
            'category' => $this->whenLoaded('category'),
            'unit_quantity' => $this->whenLoaded('unitQuantity'),
            'tax' => $this->whenLoaded('tax'),
            'supplier' => $this->whenLoaded('supplier'),
            'type' => $this->type,
            'cost_price' => $this->cost_price,
            'selling_price' => $this->selling_price,
            'stock' => $this->stock,
            'min_stock' => $this->min_stock,
            'is_low_stock' => $this->stock <= $this->min_stock,
            'image' => $this->image,
            'description' => $this->description,
            'is_active' => $this->is_active,
            'created_at' => $this->created_at,
        ];
    }
}
