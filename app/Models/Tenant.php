<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class Tenant extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'name',
        'slug',
        'license_code',
        'api_key',
        'email',
        'phone',
        'address',
        'city',
        'province',
        'postal_code',
        'tax_number',
        'logo',
        'domain',
        'owner_id',
        'plan_id',
        'status',
        'trial_ends_at',
        'suspended_at',
        'suspension_reason',
        'last_seen_at',
        'settings',
        'is_active',
    ];

    protected $casts = [
        'trial_ends_at' => 'datetime',
        'suspended_at' => 'datetime',
        'last_seen_at' => 'datetime',
        'settings' => 'array',
        'is_active' => 'boolean',
    ];

    protected static function booted(): void
    {
        static::creating(function (Tenant $tenant) {
            if (empty($tenant->slug)) {
                $tenant->slug = Str::slug($tenant->name);
            }
            if (empty($tenant->license_code) && Schema::hasColumn('tenants', 'license_code')) {
                $tenant->license_code = self::makeLicenseCode($tenant->slug ?: $tenant->name);
            }
            if (empty($tenant->api_key) && Schema::hasColumn('tenants', 'api_key')) {
                $tenant->api_key = Str::random(40);
            }
        });
    }

    public static function makeLicenseCode(string $seed): string
    {
        $clean = preg_replace('/[^A-Za-z0-9]/', '', Str::ascii($seed));
        $clean = substr(str_pad(strtoupper($clean), 4, 'X'), 0, 6);

        return 'PQ-'.$clean.'-'.strtoupper(Str::random(6));
    }

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(Plan::class);
    }

    public function subscription(): HasOne
    {
        return $this->hasOne(Subscription::class)->latestOfMany();
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class);
    }

    public function invoices(): HasMany
    {
        return $this->hasMany(Invoice::class);
    }

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    public function branches(): HasMany
    {
        return $this->hasMany(Branch::class);
    }

    public function getStatusBadgeAttribute(): string
    {
        return match ($this->status) {
            'active' => 'bg-green-100 text-green-700',
            'trial' => 'bg-blue-100 text-blue-700',
            'inactive' => 'bg-gray-100 text-gray-700',
            'suspended' => 'bg-red-100 text-red-700',
            default => 'bg-gray-100 text-gray-700',
        };
    }

    public function isTrial(): bool
    {
        return $this->status === 'trial';
    }

    public function isActive(): bool
    {
        return $this->is_active && in_array($this->status, ['active', 'trial']);
    }

    public function isExpired(): bool
    {
        return $this->trial_ends_at && $this->trial_ends_at->isPast();
    }
}
