<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Product extends Model
{
    use HasFactory;

    protected $fillable = [
        'name', 'sku', 'barcode', 'category_id', 'unit_quantity_id', 'unit_id',
        'tax_id', 'supplier_id', 'type', 'cost_price', 'selling_price', 'price', 'cost',
        'stock', 'min_stock', 'image', 'photo', 'description', 'is_active', 'active', 'category',
        'wholesale_price', 'min_wholesale', 'product_discount', 'product_tax', 'expiry_date',
    ];

    protected $casts = [
        'cost_price' => 'decimal:2',
        'selling_price' => 'decimal:2',
        'price' => 'decimal:2',
        'cost' => 'decimal:2',
        'is_active' => 'boolean',
        'active' => 'boolean',
    ];

    protected $appends = [];

    // Fallback: jika selling_price 0, pakai price (Java)
    public function getSellingPriceAttribute($value): string
    {
        if ($value && (float) $value != 0) {
            return $value;
        }

        return $this->attributes['price'] ?? $value ?? '0.00';
    }

    public function getCostPriceAttribute($value): string
    {
        if ($value && (float) $value != 0) {
            return $value;
        }

        return $this->attributes['cost'] ?? $value ?? '0.00';
    }

    // Sync saat save: selalu sinkronkan price/cost dengan selling_price/cost_price
    protected static function booted(): void
    {
        static::saving(function (Product $product) {
            if ($product->isDirty('selling_price') && $product->selling_price) {
                $product->price = $product->selling_price;
            } elseif ($product->isDirty('price') && $product->price) {
                $product->selling_price = $product->price;
            }
            if ($product->isDirty('cost_price') && $product->cost_price) {
                $product->cost = $product->cost_price;
            } elseif ($product->isDirty('cost') && $product->cost) {
                $product->cost_price = $product->cost;
            }
            // Sync active/is_active
            if ($product->isDirty('is_active')) {
                $product->active = $product->is_active;
            } elseif ($product->isDirty('active')) {
                $product->is_active = $product->active;
            }
        });
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function unitQuantity(): BelongsTo
    {
        return $this->belongsTo(UnitQuantity::class);
    }

    public function tax(): BelongsTo
    {
        return $this->belongsTo(Tax::class);
    }

    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Supplier::class);
    }

    public function transactionItems(): HasMany
    {
        return $this->hasMany(TransactionItem::class);
    }

    public function inventoryHistories(): HasMany
    {
        return $this->hasMany(InventoryHistory::class);
    }

    public function getIsLowStockAttribute(): bool
    {
        return $this->stock <= $this->min_stock;
    }
}
