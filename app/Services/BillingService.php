<?php

namespace App\Services;

use App\Models\Invoice;
use App\Models\Plan;
use App\Models\Tenant;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class BillingService
{
    public function __construct(protected IpaymuService $ipaymu) {}

    /**
     * Paid plans that a tenant can subscribe to.
     *
     * @return Collection<int, array<string, mixed>>
     */
    public function purchasablePlans(): Collection
    {
        return Plan::where('is_active', true)
            ->where('slug', '!=', 'demo')
            ->where('price', '>', 0)
            ->orderBy('price')
            ->get()
            ->map(fn (Plan $plan) => [
                'id' => $plan->id,
                'name' => $plan->name,
                'slug' => $plan->slug,
                'description' => $plan->description,
                'price' => (float) $plan->price,
                'price_yearly' => (float) ($plan->price_yearly ?? 0),
                'max_users' => $plan->max_users,
                'max_products' => $plan->max_products,
                'max_customers' => $plan->max_customers,
                'max_branches' => $plan->max_branches,
                'max_transactions_per_month' => $plan->max_transactions_per_month,
                'features' => $plan->features ?? [],
                'feature_labels' => Plan::FEATURE_LABELS,
            ]);
    }

    /**
     * Create a pending invoice and an iPaymu redirect URL for it.
     *
     * @throws RuntimeException when the payment gateway cannot be reached.
     */
    public function checkout(Tenant $tenant, Plan $plan, string $billingCycle): Invoice
    {
        $billingCycle = $billingCycle === 'yearly' ? 'yearly' : 'monthly';

        $amount = $billingCycle === 'yearly'
            ? (float) ($plan->price_yearly ?: $plan->price)
            : (float) $plan->price;

        $taxAmount = round($amount * 0.11, 2);

        $invoice = DB::transaction(fn () => Invoice::create([
            'tenant_id' => $tenant->id,
            'plan_id' => $plan->id,
            'status' => 'pending',
            'billing_cycle' => $billingCycle,
            'subtotal' => $amount,
            'tax_amount' => $taxAmount,
            'total' => $amount + $taxAmount,
            'currency' => 'IDR',
            'issued_at' => now(),
            'due_at' => now()->addDays(3),
            'items' => [
                ['description' => "Paket {$plan->name} ({$billingCycle})", 'amount' => $amount, 'quantity' => 1],
                ['description' => 'PPN 11%', 'amount' => $taxAmount, 'quantity' => 1],
            ],
        ]));

        try {
            $payment = $this->ipaymu->createRedirectPayment($invoice);
        } catch (RuntimeException $e) {
            $invoice->update(['status' => 'cancelled', 'notes' => $e->getMessage()]);

            throw $e;
        }

        $invoice->update([
            'external_id' => $payment['reference'],
            'payment_url' => $payment['url'],
            'payment_method' => 'ipaymu',
        ]);

        return $invoice->fresh();
    }
}
