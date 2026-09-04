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
            'type' => $this->type,
            'category' => $this->whenLoaded('category'),
            'category_id' => $this->category_id,
            'category_text' => $this->category, // Java varchar column
            'unit_quantity' => $this->whenLoaded('unitQuantity'),
            'unit_quantity_id' => $this->unit_quantity_id,
            'unit_id' => $this->unit_id, // Java unit_id column
            'tax' => $this->whenLoaded('tax'),
            'tax_id' => $this->tax_id,
            'supplier' => $this->whenLoaded('supplier'),
            'supplier_id' => $this->supplier_id,
            'cost_price' => $this->cost_price,
            'selling_price' => $this->selling_price,
            'price' => $this->price, // Java price column
            'cost' => $this->cost, // Java cost column
            'wholesale_price' => $this->wholesale_price,
            'min_wholesale' => $this->min_wholesale,
            'product_discount' => $this->product_discount,
            'product_tax' => $this->product_tax,
            'expiry_date' => $this->expiry_date,
            'stock' => $this->stock,
            'min_stock' => $this->min_stock,
            'is_low_stock' => $this->stock <= $this->min_stock,
            'image' => $this->image,
            'photo' => $this->photo,
            'description' => $this->description,
            'is_active' => $this->is_active,
            'active' => $this->active,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
