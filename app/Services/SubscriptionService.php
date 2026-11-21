<?php

namespace App\Services;

use App\Models\Invoice;
use App\Models\Plan;
use App\Models\Subscription;
use App\Models\Tenant;
use Carbon\CarbonInterface;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class SubscriptionService
{
    public const TRIAL_DAYS = 30;

    /**
     * Start the one-month full-feature demo on a tenant.
     */
    public function startTrial(Tenant $tenant, ?int $days = null, ?Plan $plan = null): Subscription
    {
        $days ??= self::TRIAL_DAYS;
        $plan ??= $this->trialPlan();
        $startsAt = now();
        $endsAt = $startsAt->copy()->addDays($days);

        return DB::transaction(function () use ($tenant, $plan, $startsAt, $endsAt, $days) {
            // Keep one trialing row per tenant (the legacy schema has a
            // unique tenant_id+status index that may still be present).
            $subscription = Subscription::where('tenant_id', $tenant->id)
                ->where('status', 'trialing')
                ->latest('id')
                ->first()
                ?? new Subscription(['tenant_id' => $tenant->id]);

            $subscription->fill([
                'plan_id' => $plan->id,
                'status' => 'trialing',
                'amount' => 0,
                'billing_cycle' => 'monthly',
                'starts_at' => $startsAt,
                'ends_at' => $endsAt,
                'trial_ends_at' => $endsAt,
                'metadata' => ['kind' => 'demo', 'days' => $days],
            ])->save();

            $tenant->update([
                'plan_id' => $plan->id,
                'status' => 'trial',
                'trial_ends_at' => $endsAt,
                'suspended_at' => null,
                'suspension_reason' => null,
                'is_active' => true,
            ]);

            return $subscription;
        });
    }

    /**
     * Activate or renew a paid plan after an invoice was settled.
     */
    public function activate(Tenant $tenant, Plan $plan, string $billingCycle, Invoice $invoice, ?string $externalId = null): Subscription
    {
        $billingCycle = $billingCycle === 'yearly' ? 'yearly' : 'monthly';

        return DB::transaction(function () use ($tenant, $plan, $billingCycle, $invoice, $externalId) {
            $latestEnd = Subscription::where('tenant_id', $tenant->id)
                ->whereIn('status', ['active', 'trialing'])
                ->whereNotNull('ends_at')
                ->max('ends_at');

            $startsAt = $latestEnd && now()->lt($latestEnd)
                ? Carbon::parse($latestEnd)
                : now();

            $endsAt = $billingCycle === 'yearly'
                ? $startsAt->copy()->addYearNoOverflow()
                : $startsAt->copy()->addMonthNoOverflow();

            // Reuse an active/trialing row where possible so renewals also
            // work on databases that still carry the old unique index.
            $subscription = Subscription::where('tenant_id', $tenant->id)
                ->where('status', 'active')
                ->latest('id')
                ->first()
                ?? Subscription::where('tenant_id', $tenant->id)
                    ->where('status', 'trialing')
                    ->latest('id')
                    ->first()
                ?? Subscription::where('tenant_id', $tenant->id)->latest('id')->first()
                ?? new Subscription(['tenant_id' => $tenant->id]);

            $subscription->fill([
                'plan_id' => $plan->id,
                'status' => 'active',
                'amount' => $plan->price,
                'billing_cycle' => $billingCycle,
                'starts_at' => $startsAt,
                'ends_at' => $endsAt,
                'external_id' => $externalId,
                'metadata' => [
                    'invoice_id' => $invoice->id,
                    'invoice_number' => $invoice->invoice_number,
                    'payment_gateway' => 'ipaymu',
                ],
            ])->save();

            $tenant->update([
                'plan_id' => $plan->id,
                'status' => 'active',
                'trial_ends_at' => $endsAt,
                'suspended_at' => null,
                'suspension_reason' => null,
                'is_active' => true,
            ]);

            if (! $invoice->isPaid()) {
                $invoice->update([
                    'status' => 'paid',
                    'paid_at' => now(),
                    'amount_paid' => $invoice->total,
                    'payment_method' => 'ipaymu',
                    'external_id' => $externalId ?: $invoice->external_id,
                ]);
            }

            return $subscription;
        });
    }

    /**
     * Idempotently settle an invoice and extend the tenant subscription.
     */
    public function markInvoicePaid(Invoice $invoice, ?string $externalId = null, array $metadata = []): ?Subscription
    {
        $invoice->refresh();

        if ($invoice->isPaid()) {
            return $invoice->tenant?->subscription;
        }

        $plan = $invoice->plan;
        if (! $plan) {
            return null;
        }

        $tenant = $invoice->tenant;
        if (! $tenant) {
            return null;
        }

        $subscription = $this->activate(
            $tenant,
            $plan,
            $invoice->billing_cycle ?: 'monthly',
            $invoice,
            $externalId,
        );

        if ($metadata !== []) {
            $subscription->update(['metadata' => array_merge($subscription->metadata ?? [], $metadata)]);
        }

        return $subscription;
    }

    /**
     * Manual activation by Super Admin: grants a fresh active period without
     * requiring an invoice, using the tenant's current plan (or the demo plan).
     */
    public function reactivate(Tenant $tenant, int $days = 30): Subscription
    {
        $plan = $tenant->plan ?? $this->trialPlan();
        $startsAt = now();
        $endsAt = $startsAt->copy()->addDays($days);

        return DB::transaction(function () use ($tenant, $plan, $startsAt, $endsAt) {
            $subscription = Subscription::where('tenant_id', $tenant->id)
                ->where('status', 'active')
                ->latest('id')
                ->first()
                ?? Subscription::where('tenant_id', $tenant->id)->latest('id')->first()
                ?? new Subscription(['tenant_id' => $tenant->id]);

            $subscription->fill([
                'plan_id' => $plan->id,
                'status' => 'active',
                'billing_cycle' => 'monthly',
                'starts_at' => $startsAt,
                'ends_at' => $endsAt,
                'cancelled_at' => null,
            ])->save();

            $tenant->update([
                'plan_id' => $plan->id,
                'status' => 'active',
                'trial_ends_at' => $endsAt,
                'suspended_at' => null,
                'suspension_reason' => null,
                'is_active' => true,
            ]);

            return $subscription;
        });
    }

    public function expire(Tenant $tenant): void
    {
        $tenant->update(['status' => 'expired', 'is_active' => false]);

        $subscription = Subscription::where('tenant_id', $tenant->id)
            ->whereIn('status', ['active', 'trialing', 'past_due'])
            ->latest('id')
            ->first();

        $subscription?->update(['status' => 'expired']);
    }

    /**
     * Keep tenant status in sync with the subscription/trial end date.
     * Called lazily on authenticated requests, so no scheduler is required.
     */
    public function syncStatus(Tenant $tenant): void
    {
        if (in_array($tenant->status, ['suspended', 'inactive'], true)) {
            return;
        }

        $subscription = $tenant->subscription;

        if ($tenant->status === 'trial' && $tenant->trial_ends_at?->isPast()) {
            $this->expire($tenant);

            return;
        }

        if ($tenant->status === 'active' && $subscription && $subscription->ends_at?->isPast()) {
            $this->expire($tenant);
        }
    }

    public function isExpired(Tenant $tenant): bool
    {
        if ($tenant->status === 'expired') {
            return true;
        }

        if ($tenant->status === 'trial') {
            return $tenant->trial_ends_at?->isPast() ?? false;
        }

        if ($tenant->status === 'active') {
            $subscription = $tenant->subscription;

            return $subscription?->ends_at?->isPast() ?? false;
        }

        return false;
    }

    public function daysRemaining(Tenant $tenant): int
    {
        $endsAt = $tenant->subscription?->ends_at ?? $tenant->trial_ends_at;

        return $endsAt ? max(0, (int) now()->diffInDays($endsAt, false)) : 0;
    }

    public function trialPlan(): Plan
    {
        $plan = Plan::where('slug', 'demo')->first();

        if ($plan) {
            return $plan;
        }

        return Plan::create([
            'name' => 'Demo 30 Hari',
            'slug' => 'demo',
            'description' => 'Akses penuh semua fitur selama 30 hari.',
            'price' => 0,
            'price_yearly' => 0,
            'billing_cycle' => 30,
            'trial_days' => self::TRIAL_DAYS,
            'max_users' => 10,
            'max_products' => 2000,
            'max_customers' => 1000,
            'max_transactions_per_month' => 10000,
            'max_branches' => 5,
            'features' => array_keys(Plan::FEATURE_LABELS),
            'is_active' => true,
            'sort_order' => 0,
        ]);
    }

    public function effectiveEndsAt(?Tenant $tenant): ?CarbonInterface
    {
        return $tenant?->subscription?->ends_at ?? $tenant?->trial_ends_at;
    }
}
