<?php

namespace App\Http\Middleware;

use App\Models\Plan;
use App\Services\PlanService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsurePlanFeature
{
    public function handle(Request $request, Closure $next, string $feature): Response
    {
        $user = $request->user();

        if (! $user || ! $user->tenant_id) {
            return $next($request);
        }

        $planService = app(PlanService::class);

        if ($planService->hasFeature($feature)) {
            return $next($request);
        }

        $label = Plan::FEATURE_LABELS[$feature] ?? $feature;
        $message = "Fitur {$label} tidak tersedia pada paket Anda. Upgrade paket untuk mengakses fitur ini.";

        if ($request->expectsJson() || $request->is('api/*')) {
            return response()->json([
                'message' => $message,
                'code' => 'feature_not_in_plan',
                'feature' => $feature,
                'limits' => $planService->getLimitsSummary(),
            ], 403);
        }

        return back()->with('error', $message);
    }
}
