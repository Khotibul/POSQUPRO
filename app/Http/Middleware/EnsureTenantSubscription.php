<?php

namespace App\Http\Middleware;

use App\Services\PlanService;
use App\Services\SubscriptionService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureTenantSubscription
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user || ! $user->tenant_id) {
            return $next($request);
        }

        $tenant = $user->tenant;
        if (! $tenant) {
            return $next($request);
        }

        $subscriptions = app(SubscriptionService::class);
        $subscriptions->syncStatus($tenant);
        $tenant->refresh();

        $planService = app(PlanService::class)->setTenant($tenant);

        $billingRequest = $request->is('billing', 'billing/*')
            || $request->routeIs('billing.*')
            || $request->is('logout');

        if (in_array($tenant->status, ['suspended', 'inactive'], true)) {
            if ($billingRequest) {
                return $next($request);
            }

            return $this->deny(
                $request,
                $tenant->status === 'suspended'
                    ? 'Akun tenant Anda ditangguhkan. Hubungi administrator POSQUPRO.'
                    : 'Akun tenant Anda tidak aktif.',
                403,
            );
        }

        if ($planService->isExpired()) {
            if ($billingRequest) {
                return $next($request);
            }

            return $this->deny(
                $request,
                'Masa demo/langganan Anda telah berakhir. Pilih paket Profesional, Bisnis, atau Enterprise untuk melanjutkan.',
                402,
            );
        }

        return $next($request);
    }

    protected function deny(Request $request, string $message, int $status): Response
    {
        if ($request->expectsJson() || $request->is('api/*')) {
            return response()->json([
                'message' => $message,
                'code' => 'subscription_inactive',
            ], $status);
        }

        return redirect()
            ->route('billing.index')
            ->with('error', $message);
    }
}
