<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Payment extends Model
{
    use HasFactory;

    /**
     * Shared Java table `payments` (no updated_at column).
     */
    public $timestamps = false;

    protected $fillable = ['sale_id', 'amount', 'method', 'reference_no'];

    protected $casts = [
        'amount' => 'decimal:2',
    ];
}
