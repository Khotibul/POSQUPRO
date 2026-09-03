<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class ActivityLog extends Model
{
    use HasFactory;

    protected $fillable = ['subject_type', 'subject_id', 'user_id', 'event', 'description', 'properties', 'ip_address', 'user_agent'];

    protected $casts = [
        'properties' => 'array',
    ];

    public function subject(): MorphTo
    {
        return $this->morphTo();
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public static function log(string $event, ?string $description = null, array $properties = [], ?Model $subject = null): void
    {
        self::create([
            'subject_type' => $subject?->getMorphClass(),
            'subject_id' => $subject?->id,
            'user_id' => auth()->id(),
            'event' => $event,
            'description' => $description,
            'properties' => $properties,
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),
        ]);
    }
}
