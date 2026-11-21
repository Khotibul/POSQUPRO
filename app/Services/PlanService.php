<?php

namespace App\Services;

use App\Models\Branch;
use App\Models\Customer;
use App\Models\Plan;
use App\Models\Product;
use App\Models\Subscription;
use App\Models\Tenant;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class PlanService
{
    protected ?Tenant $tenant;

    protected ?Plan $plan;

    public function __construct(?Tenant $tenant = null)
    {
        $this->tenant = $tenant ?? (auth()->check() ? auth()->user()->tenant : null);
        $this->plan = $this->tenant?->plan;
    }

    public function setTenant(Tenant $tenant): self
    {
        $this->tenant = $tenant;
        $this->plan = $tenant->plan;

        return $this;
    }

    public function getPlan(): ?Plan
    {
        return $this->plan;
    }

    public function getTenant(): ?Tenant
    {
        return $this->tenant;
    }

    /**
     * Installations without a tenant/plan keep working as before; limits only
     * apply to tenants that actually have a subscription plan.
     */
    public function isRestricted(): bool
    {
        return $this->tenant !== null && $this->plan !== null;
    }

    protected function withinLimit(int $current, ?int $max): bool
    {
        if (! $this->isRestricted()) {
            return true;
        }

        return $max === null || $max <= 0 || $current < $max;
    }

    // ── LIMIT CHECKS ──────────────────────────────────────────

    public function getUserCount(): int
    {
        return $this->tenant ? User::where('tenant_id', $this->tenant->id)->count() : 0;
    }

    public function canAddUser(): bool
    {
        return $this->withinLimit($this->getUserCount(), $this->plan?->max_users);
    }

    public function getProductCount(): int
    {
        return $this->tenant ? Product::where('tenant_id', $this->tenant->id)->count() : 0;
    }

    public function canAddProduct(): bool
    {
        return $this->withinLimit($this->getProductCount(), $this->plan?->max_products);
    }

    public function getCustomerCount(): int
    {
        if (! $this->tenant || ! Schema::hasColumn('customers', 'tenant_id')) {
            return 0;
        }

        return Customer::where('tenant_id', $this->tenant->id)->count();
    }

    public function canAddCustomer(): bool
    {
        return $this->withinLimit($this->getCustomerCount(), $this->plan?->max_customers);
    }

    public function getBranchCount(): int
    {
        return $this->tenant ? Branch::where('tenant_id', $this->tenant->id)->count() : 0;
    }

    public function canAddBranch(): bool
    {
        return $this->withinLimit($this->getBranchCount(), $this->plan?->max_branches);
    }

    public function getMonthlyTransactionCount(): int
    {
        if (! $this->tenant) {
            return 0;
        }

        $from = now()->startOfMonth();
        $to = now()->endOfMonth();

        $count = 0;
        if (Schema::hasColumn('transactions', 'tenant_id')) {
            $count += Transaction::where('tenant_id', $this->tenant->id)
                ->whereBetween('created_at', [$from, $to])
                ->count();
        }

        // Web POS writes to the shared Java `sales` table.
        if (Schema::hasTable('sales') && Schema::hasColumn('sales', 'cashier_id')) {
            $userIds = User::where('tenant_id', $this->tenant->id)->pluck('id');
            $count += DB::table('sales')
                ->whereIn('cashier_id', $userIds)
                ->whereBetween('created_at', [$from, $to])
                ->count();
        }

        return $count;
    }

    public function canAddTransaction(): bool
    {
        return $this->withinLimit($this->getMonthlyTransactionCount(), $this->plan?->max_transactions_per_month);
    }

    public function limitMessage(string $label, int $current, ?int $max): string
    {
        if (! $this->plan) {
            return 'Tidak ada paket aktif.';
        }

        if ($max === null || $max <= 0) {
            return "{$label} tidak dibatasi.";
        }

        return "{$current}/{$max} {$label} terpakai. Upgrade paket untuk menambah data.";
    }

    public function getUserLimitMessage(): string
    {
        return $this->limitMessage('pengguna', $this->getUserCount(), $this->plan?->max_users);
    }

    public function getProductLimitMessage(): string
    {
        return $this->limitMessage('produk', $this->getProductCount(), $this->plan?->max_products);
    }

    public function getBranchLimitMessage(): string
    {
        return $this->limitMessage('cabang', $this->getBranchCount(), $this->plan?->max_branches);
    }

    // ── FEATURE CHECKS ────────────────────────────────────────

    public function hasFeature(string $feature): bool
    {
        if (! $this->isRestricted()) {
            return true;
        }

        return in_array($feature, $this->plan->features ?? [], true);
    }

    public function getFeatures(): array
    {
        return $this->isRestricted() ? ($this->plan->features ?? []) : array_keys(Plan::FEATURE_LABELS);
    }

    // ── SUBSCRIPTION STATUS ───────────────────────────────────

    public function getSubscription(): ?Subscription
    {
        return $this->tenant?->subscription;
    }

    public function getStatus(): string
    {
        return $this->tenant?->status ?? 'none';
    }

    public function isExpired(): bool
    {
        return $this->tenant ? app(SubscriptionService::class)->isExpired($this->tenant) : false;
    }

    public function canAccess(): bool
    {
        if (! $this->tenant) {
            return true;
        }

        if (in_array($this->tenant->status, ['suspended', 'inactive', 'expired'], true)) {
            return false;
        }

        return ! $this->isExpired();
    }

    public function getSubscriptionSummary(): array
    {
        $subscription = $this->getSubscription();

        return [
            'status' => $subscription?->status ?? ($this->tenant?->status === 'trial' ? 'trialing' : null),
            'is_trial' => $this->tenant?->status === 'trial',
            'is_expired' => $this->isExpired(),
            'ends_at' => app(SubscriptionService::class)->effectiveEndsAt($this->tenant)?->toIso8601String(),
            'days_remaining' => $this->tenant ? app(SubscriptionService::class)->daysRemaining($this->tenant) : 0,
            'billing_cycle' => $subscription?->billing_cycle,
        ];
    }

    public function isOverLimits(): bool
    {
        return ! $this->canAddUser()
            || ! $this->canAddProduct()
            || ! $this->canAddCustomer()
            || ! $this->canAddBranch()
            || ! $this->canAddTransaction();
    }

    public function getLimitsSummary(): array
    {
        if (! $this->plan) {
            return [
                'has_plan' => false,
                'plan_name' => 'Tidak ada paket',
                'plan_slug' => null,
                'users' => ['current' => 0, 'max' => 0, 'ok' => true, 'unlimited' => true],
                'products' => ['current' => 0, 'max' => 0, 'ok' => true, 'unlimited' => true],
                'customers' => ['current' => 0, 'max' => 0, 'ok' => true, 'unlimited' => true],
                'branches' => ['current' => 0, 'max' => 0, 'ok' => true, 'unlimited' => true],
                'transactions_month' => ['current' => 0, 'max' => 0, 'ok' => true, 'unlimited' => true],
                'features' => array_keys(Plan::FEATURE_LABELS),
                'subscription' => ['status' => null, 'is_trial' => false, 'is_expired' => false, 'ends_at' => null, 'days_remaining' => 0],
            ];
        }

        return [
            'has_plan' => true,
            'plan_name' => $this->plan->name,
            'plan_slug' => $this->plan->slug,
            'users' => $this->limitRow($this->getUserCount(), $this->plan->max_users, $this->canAddUser()),
            'products' => $this->limitRow($this->getProductCount(), $this->plan->max_products, $this->canAddProduct()),
            'customers' => $this->limitRow($this->getCustomerCount(), $this->plan->max_customers, $this->canAddCustomer()),
            'branches' => $this->limitRow($this->getBranchCount(), $this->plan->max_branches, $this->canAddBranch()),
            'transactions_month' => $this->limitRow($this->getMonthlyTransactionCount(), $this->plan->max_transactions_per_month, $this->canAddTransaction()),
            'features' => $this->getFeatures(),
            'subscription' => $this->getSubscriptionSummary(),
        ];
    }

    private function limitRow(int $current, ?int $max, bool $ok): array
    {
        return [
            'current' => $current,
            'max' => $max ?? 0,
            'ok' => $ok,
            'unlimited' => $max === null || $max <= 0,
        ];
    }
}
