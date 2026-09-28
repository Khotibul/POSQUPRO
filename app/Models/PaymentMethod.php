<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PaymentMethod extends Model
{
    // Shared table has no updated_at column
    public $timestamps = false;

    protected $fillable = ['name', 'label', 'active'];

    protected $casts = [
        'active' => 'boolean',
    ];
}
