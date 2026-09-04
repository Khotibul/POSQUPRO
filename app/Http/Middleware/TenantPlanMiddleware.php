<?php

namespace App\Http\Middleware;

use App\Services\PlanService;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Schema;
use Symfony\Component\HttpFoundation\Response;

class TenantPlanMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        try {
            if (! $request->user()) {
                return $next($request);
            }

            $user = $request->user();

            if (! Schema::hasTable('tenants') || ! Schema::hasTable('plans')) {
                return $next($request);
            }

            $tenant = $user->tenant;

            if ($tenant) {
                $planService = App::make(PlanService::class);
                $planService->setTenant($tenant);

                inertia()->share('tenant', [
                    'id' => $tenant->id,
                    'name' => $tenant->name,
                    'status' => $tenant->status,
                    'plan' => $tenant->plan ? [
                        'id' => $tenant->plan->id,
                        'name' => $tenant->plan->name,
                        'features' => $tenant->plan->features ?? [],
                    ] : null,
                    'limits' => $planService->getLimitsSummary(),
                ]);
            } else {
                inertia()->share('tenant', null);
            }
        } catch (\Exception $e) {
            // Gracefully handle missing tables/columns in test/dev
        }

        return $next($request);
    }
}
