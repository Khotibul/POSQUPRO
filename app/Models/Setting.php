<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Setting extends Model
{
    use HasFactory;

    protected $fillable = ['key', 'group', 'value', 'type', 'label', 'description', 'is_public'];

    protected $casts = [
        'is_public' => 'boolean',
    ];

    public function getTypedValueAttribute()
    {
        return match ($this->type) {
            'boolean' => (bool) $this->value,
            'integer' => (int) $this->value,
            'decimal' => (float) $this->value,
            'json' => json_decode($this->value, true),
            default => $this->value,
        };
    }

    public static function get(string $key, $default = null)
    {
        return self::where('key', $key)->first()?->typed_value ?? $default;
    }

    public static function set(string $key, $value, string $type = 'string', string $group = 'general'): self
    {
        return self::updateOrCreate(
            ['key' => $key],
            ['value' => is_array($value) || is_object($value) ? json_encode($value) : (string) $value, 'type' => $type, 'group' => $group]
        );
    }
}
