<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Expense extends Model
{
    use HasFactory;

    /**
     * Shared Java/desktop table: expenses
     * (branch_id, shift_id, user_id, category, description, amount, created_at).
     */
    protected $fillable = [
        'branch_id', 'shift_id', 'user_id', 'category', 'description', 'amount',
    ];

    public $timestamps = false;

    protected $casts = [
        'amount' => 'integer',
    ];

    public function branch(): BelongsTo
    {
        return $this->belongsTo(Branch::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
