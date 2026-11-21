<?php

namespace App\Http\Controllers;

use App\Models\Invoice;
use App\Models\Plan;
use App\Services\BillingService;
use App\Services\IpaymuService;
use App\Services\PlanService;
use App\Services\SubscriptionService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Inertia\Inertia;
use RuntimeException;

class BillingController extends Controller
{
    public function index(Request $request)
    {
        $tenant = $request->user()->tenant;

        if (! $tenant) {
            // Super Admin tidak memiliki tenant; arahkan ke pengelolaan paket.
            return redirect()->route('plans.index');
        }

        abort_unless($request->user()->hasAnyRole(['Admin', 'Super Admin']), 403);

        $planService = app(PlanService::class)->setTenant($tenant);
        $subscription = app(SubscriptionService::class);

        $plans = app(BillingService::class)->purchasablePlans();

        $invoices = $tenant->invoices()
            ->with('plan:id,name')
            ->latest()
            ->limit(12)
            ->get();

        return Inertia::render('Billing/Subscription', [
            'plans' => $plans,
            'invoices' => $invoices,
            'limits' => $planService->getLimitsSummary(),
            'subscription' => $planService->getSubscriptionSummary(),
            'tenantStatus' => $tenant->status,
            'daysRemaining' => $subscription->daysRemaining($tenant),
            'ipaymuEnabled' => app(IpaymuService::class)->isConfigured(),
        ]);
    }

    public function checkout(Request $request, BillingService $billing)
    {
        abort_unless($request->user()->hasAnyRole(['Admin', 'Super Admin']), 403);

        $tenant = $request->user()->tenant;
        if (! $tenant) {
            return redirect()->route('plans.index');
        }

        if ($tenant->status === 'suspended') {
            return back()->with('error', 'Akun tenant ditangguhkan oleh administrator. Hubungi POSQUPRO sebelum melakukan pembayaran.');
        }

        $data = $request->validate([
            'plan_id' => ['required', 'exists:plans,id'],
            'billing_cycle' => ['required', 'in:monthly,yearly'],
        ]);

        $plan = Plan::where('is_active', true)->findOrFail($data['plan_id']);

        if ($plan->slug === 'demo' || (float) $plan->price <= 0) {
            return back()->with('error', 'Paket demo tidak dapat dibeli.');
        }

        try {
            $invoice = $billing->checkout($tenant, $plan, $data['billing_cycle']);
        } catch (RuntimeException $e) {
            return back()->with('error', $e->getMessage());
        }

        return Inertia::location($invoice->payment_url);
    }

    public function paymentReturn(Request $request, Invoice $invoice, IpaymuService $ipaymu)
    {
        $tenant = $request->user()->tenant;
        abort_unless($tenant && $invoice->tenant_id === $tenant->id, 403);

        if ($invoice->isPaid()) {
            return redirect()->route('billing.index')->with('success', 'Pembayaran sudah diterima. Paket Anda aktif.');
        }

        $trxId = $request->query('trx_id') ?? $request->query('transaction_id');

        if ($trxId) {
            $checked = $ipaymu->checkTransaction($trxId);
            $paid = $checked && in_array((int) ($checked['Status'] ?? 0), [1, 6, 7], true);
            $amount = (float) ($checked['Amount'] ?? $checked['Total'] ?? 0);

            if ($paid && ($amount <= 0 || $amount + 0.5 >= (float) $invoice->total)) {
                app(SubscriptionService::class)->markInvoicePaid($invoice, (string) $trxId);

                return redirect()->route('billing.index')->with('success', 'Pembayaran berhasil. Paket Anda sudah aktif.');
            }
        }

        Log::info('iPaymu return without settled transaction', ['invoice' => $invoice->id, 'query' => $request->query()]);

        return redirect()->route('billing.index')->with(
            'error',
            'Pembayaran belum terkonfirmasi. Status akan diperbarui otomatis setelah callback iPaymu diterima.'
        );
    }
}
