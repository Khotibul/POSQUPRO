<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StockCountItem extends Model
{
    use HasFactory;

    protected $fillable = ['stock_count_id', 'product_id', 'system_quantity', 'counted_quantity', 'variance', 'notes'];

    public function stockCount(): BelongsTo
    {
        return $this->belongsTo(StockCount::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    protected static function booted(): void
    {
        static::saving(function ($item) {
            if ($item->counted_quantity !== null) {
                $item->variance = $item->counted_quantity - $item->system_quantity;
            }
        });
    }
}
