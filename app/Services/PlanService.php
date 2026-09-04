<?php

namespace App\Services;

use App\Models\Plan;
use App\Models\Tenant;
use App\Models\User;
use App\Models\Product;
use App\Models\Branch;
use Illuminate\Support\Facades\DB;

class PlanService
{
    protected ?Tenant $tenant;
    protected ?Plan $plan;

    public function __construct(?Tenant $tenant = null)
    {
        $this->tenant = $tenant;
        $this->plan = $tenant?->plan;
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

    // ── LIMIT CHECKS ──────────────────────────────────────────

    public function getUserCount(): int
    {
        if (!$this->tenant) {
            return 0;
        }
        try {
            return User::where('tenant_id', $this->tenant->id)->count();
        } catch (\Exception $e) {
            return 0;
        }
    }

    public function canAddUser(): bool
    {
        if (!$this->plan || !$this->tenant) {
            return false;
        }
        return $this->getUserCount() < $this->plan->max_users;
    }

    public function getUserLimitMessage(): string
    {
        if (!$this->plan) {
            return 'Tidak ada paket aktif';
        }
        $current = $this->getUserCount();
        return "{$current}/{$this->plan->max_users} pengguna terpakai";
    }

    public function getProductCount(): int
    {
        if (!$this->tenant) {
            return 0;
        }
        try {
            return Product::where('tenant_id', $this->tenant->id)->count();
        } catch (\Exception $e) {
            return 0;
        }
    }

    public function canAddProduct(): bool
    {
        if (!$this->plan || !$this->tenant) {
            return false;
        }
        return $this->getProductCount() < $this->plan->max_products;
    }

    public function getProductLimitMessage(): string
    {
        if (!$this->plan) {
            return 'Tidak ada paket aktif';
        }
        $current = $this->getProductCount();
        return "{$current}/{$this->plan->max_products} produk terpakai";
    }

    public function getBranchCount(): int
    {
        if (!$this->tenant) {
            return 0;
        }
        try {
            return Branch::where('tenant_id', $this->tenant->id)->count();
        } catch (\Exception $e) {
            return 0;
        }
    }

    public function canAddBranch(): bool
    {
        if (!$this->plan || !$this->tenant) {
            return false;
        }
        return $this->getBranchCount() < $this->plan->max_branches;
    }

    public function getBranchLimitMessage(): string
    {
        if (!$this->plan) {
            return 'Tidak ada paket aktif';
        }
        $current = $this->getBranchCount();
        return "{$current}/{$this->plan->max_branches} cabang terpakai";
    }

    // ── FEATURE CHECKS ────────────────────────────────────────

    public function hasFeature(string $feature): bool
    {
        if (!$this->plan) {
            return false;
        }
        return in_array($feature, $this->plan->features ?? []);
    }

    public function getFeatures(): array
    {
        return $this->plan?->features ?? [];
    }

    // ── OVERALL STATUS ────────────────────────────────────────

    public function isOverLimits(): bool
    {
        return !$this->canAddUser() || !$this->canAddProduct() || !$this->canAddBranch();
    }

    public function getLimitsSummary(): array
    {
        if (!$this->plan) {
            return [
                'has_plan' => false,
                'plan_name' => 'Tidak ada paket',
                'users' => ['current' => 0, 'max' => 0, 'ok' => false],
                'products' => ['current' => 0, 'max' => 0, 'ok' => false],
                'branches' => ['current' => 0, 'max' => 0, 'ok' => false],
                'features' => [],
            ];
        }

        return [
            'has_plan' => true,
            'plan_name' => $this->plan->name,
            'users' => [
                'current' => $this->getUserCount(),
                'max' => $this->plan->max_users,
                'ok' => $this->canAddUser(),
            ],
            'products' => [
                'current' => $this->getProductCount(),
                'max' => $this->plan->max_products,
                'ok' => $this->canAddProduct(),
            ],
            'branches' => [
                'current' => $this->getBranchCount(),
                'max' => $this->plan->max_branches,
                'ok' => $this->canAddBranch(),
            ],
            'features' => $this->getFeatures(),
        ];
    }
}
