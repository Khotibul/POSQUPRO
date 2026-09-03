<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class UnitQuantity extends Model
{
    use HasFactory;

    protected $fillable = ['name', 'symbol', 'description'];

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }
}
