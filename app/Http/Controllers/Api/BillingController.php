<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Plan;
use App\Services\BillingService;
use App\Services\IpaymuService;
use App\Services\PlanService;
use App\Services\SubscriptionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class BillingController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $tenant = $request->user()->tenant;

        if (! $tenant) {
            return response()->json(['subscription' => null, 'limits' => null, 'plans' => []]);
        }

        abort_unless($request->user()->hasAnyRole(['Admin', 'Super Admin']), 403);

        $planService = app(PlanService::class)->setTenant($tenant);
        $subscription = app(SubscriptionService::class);

        $invoices = $tenant->invoices()
            ->with('plan:id,name')
            ->latest()
            ->limit(12)
            ->get()
            ->map(fn ($invoice) => [
                'id' => $invoice->id,
                'invoice_number' => $invoice->invoice_number,
                'plan_name' => $invoice->plan?->name,
                'status' => $invoice->status,
                'billing_cycle' => $invoice->billing_cycle,
                'total' => (float) $invoice->total,
                'currency' => $invoice->currency,
                'issued_at' => $invoice->issued_at?->toIso8601String(),
                'due_at' => $invoice->due_at?->toIso8601String(),
                'paid_at' => $invoice->paid_at?->toIso8601String(),
                'payment_url' => $invoice->status === 'pending' ? $invoice->payment_url : null,
            ]);

        return response()->json([
            'status' => $tenant->status,
            'subscription' => $planService->getSubscriptionSummary(),
            'plan' => $tenant->plan ? [
                'id' => $tenant->plan->id,
                'name' => $tenant->plan->name,
                'slug' => $tenant->plan->slug,
            ] : null,
            'limits' => $planService->getLimitsSummary(),
            'features' => $planService->getFeatures(),
            'feature_labels' => Plan::FEATURE_LABELS,
            'days_remaining' => $subscription->daysRemaining($tenant),
            'ipaymu_enabled' => app(IpaymuService::class)->isConfigured(),
            'billing_url' => route('billing.index'),
            'plans' => app(BillingService::class)->purchasablePlans(),
            'invoices' => $invoices,
        ]);
    }

    public function checkout(Request $request, BillingService $billing): JsonResponse
    {
        abort_unless($request->user()->hasAnyRole(['Admin', 'Super Admin']), 403);

        $tenant = $request->user()->tenant;
        if (! $tenant) {
            return response()->json(['message' => 'Akun ini tidak terhubung ke tenant.'], 422);
        }

        if ($tenant->status === 'suspended') {
            return response()->json([
                'message' => 'Akun tenant ditangguhkan oleh administrator. Hubungi POSQUPRO sebelum melakukan pembayaran.',
            ], 403);
        }

        $data = $request->validate([
            'plan_id' => ['required', 'exists:plans,id'],
            'billing_cycle' => ['required', 'in:monthly,yearly'],
        ]);

        $plan = Plan::where('is_active', true)->findOrFail($data['plan_id']);

        if ($plan->slug === 'demo' || (float) $plan->price <= 0) {
            return response()->json(['message' => 'Paket demo tidak dapat dibeli.'], 422);
        }

        try {
            $invoice = $billing->checkout($tenant, $plan, $data['billing_cycle']);
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 502);
        }

        return response()->json([
            'message' => 'Invoice dibuat. Selesaikan pembayaran melalui tautan iPaymu.',
            'invoice' => [
                'id' => $invoice->id,
                'invoice_number' => $invoice->invoice_number,
                'status' => $invoice->status,
                'billing_cycle' => $invoice->billing_cycle,
                'subtotal' => (float) $invoice->subtotal,
                'tax_amount' => (float) $invoice->tax_amount,
                'total' => (float) $invoice->total,
                'currency' => $invoice->currency,
                'due_at' => $invoice->due_at?->toIso8601String(),
            ],
            'payment_url' => $invoice->payment_url,
        ], 201);
    }
}
