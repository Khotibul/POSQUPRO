<?php

namespace App\Http\Controllers;

use App\Models\Tenant;
use App\Models\Plan;
use App\Models\Invoice;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;

class SaasController extends Controller
{
    public function dashboard()
    {
        $stats = [
            'total_tenants' => Tenant::count(),
            'active_tenants' => Tenant::where('status', 'active')->count(),
            'trial_tenants' => Tenant::where('status', 'trial')->count(),
            'suspended_tenants' => Tenant::where('status', 'suspended')->count(),
            'total_users' => User::count(),
            'total_revenue' => Invoice::where('status', 'paid')->sum('total'),
            'monthly_revenue' => Invoice::where('status', 'paid')->whereMonth('paid_at', now()->month)->whereYear('paid_at', now()->year)->sum('total'),
            'outstanding' => Invoice::where('status', 'pending')->sum('total'),
        ];

        $recentTenants = Tenant::with(['owner', 'plan'])->latest()->limit(5)->get();
        $recentInvoices = Invoice::with(['tenant', 'plan'])->latest()->limit(10)->get();
        $planDistribution = Plan::withCount('tenants')->orderBy('sort_order')->get();

        // MySQL-compatible: DATE_FORMAT instead of strftime
        $revenueByMonth = Invoice::where('status', 'paid')
            ->where('paid_at', '>=', now()->subMonths(12))
            ->selectRaw("DATE_FORMAT(paid_at, '%Y-%m') as month, sum(total) as revenue, count(*) as count")
            ->groupByRaw("DATE_FORMAT(paid_at, '%Y-%m')")
            ->orderBy('month')
            ->get();

        return Inertia::render('Saas/Dashboard', compact(
            'stats', 'recentTenants', 'recentInvoices', 'planDistribution', 'revenueByMonth'
        ));
    }
}
