<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Plan extends Model
{
    use HasFactory;

    /** @var array<string, string> */
    public const FEATURE_LABELS = [
        'pos' => 'POS / Kasir',
        'products' => 'Produk & Stok',
        'customers' => 'Pelanggan',
        'suppliers' => 'Supplier',
        'inventory' => 'Inventory',
        'expenses' => 'Pengeluaran',
        'users' => 'Pengguna & RBAC',
        'reports' => 'Laporan & Analitik',
        'purchase_orders' => 'Purchase Order',
        'stock_counts' => 'Stock Opname',
        'multi_branch' => 'Multi Cabang & Gudang',
        'api_access' => 'Akses API / Mobile',
        'priority_support' => 'Priority Support',
    ];

    protected $fillable = [
        'name',
        'slug',
        'description',
        'price',
        'price_yearly',
        'currency',
        'billing_cycle',
        'trial_days',
        'max_users',
        'max_products',
        'max_customers',
        'max_transactions_per_month',
        'max_branches',
        'features',
        'is_active',
        'sort_order',
    ];

    protected $casts = [
        'price' => 'decimal:2',
        'price_yearly' => 'decimal:2',
        'features' => 'array',
        'is_active' => 'boolean',
    ];

    /**
     * Zero means unlimited; consumers should use PlanService helpers.
     */
    public function isUnlimited(string $limit): bool
    {
        return (int) ($this->{$limit} ?? 0) <= 0;
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class);
    }

    public function invoices(): HasMany
    {
        return $this->hasMany(Invoice::class);
    }

    public function tenants(): HasMany
    {
        return $this->hasMany(Tenant::class);
    }
}
