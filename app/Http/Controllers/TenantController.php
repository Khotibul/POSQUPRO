<?php

namespace App\Http\Controllers;

use App\Models\Plan;
use App\Models\Tenant;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;

class TenantController extends Controller
{
    public function index(Request $request)
    {
        $tenants = Tenant::with(['owner', 'plan'])
            ->when($request->search, fn ($q, $s) => $q->where('name', 'like', "%{$s}%")->orWhere('email', 'like', "%{$s}%"))
            ->when($request->status, fn ($q, $s) => $q->where('status', $s))
            ->when($request->plan_id, fn ($q, $p) => $q->where('plan_id', $p))
            ->latest()
            ->paginate(15)
            ->withQueryString();

        $plans = Plan::where('is_active', true)->orderBy('sort_order')->get();

        // Manual stats query for reliability
        $stats = [
            'total' => Tenant::count(),
            'active' => Tenant::where('status', 'active')->count(),
            'trial' => Tenant::where('status', 'trial')->count(),
            'suspended' => Tenant::where('status', 'suspended')->count(),
            'revenue' => DB::table('invoices')->where('status', 'paid')->sum('total'),
        ];

        return Inertia::render('Tenants/Index', compact('tenants', 'plans', 'stats'));
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'nullable|email|max:255',
            'phone' => 'nullable|string|max:30',
            'address' => 'nullable|string',
            'city' => 'nullable|string|max:100',
            'province' => 'nullable|string|max:100',
            'owner_name' => 'nullable|string|max:255',
            'owner_email' => 'nullable|email|max:255',
            'plan_id' => 'nullable|exists:plans,id',
        ]);

        $tenant = Tenant::create([
            'name' => $validated['name'],
            'email' => $validated['email'] ?? $validated['owner_email'] ?? null,
            'phone' => $validated['phone'] ?? null,
            'address' => $validated['address'] ?? null,
            'city' => $validated['city'] ?? null,
            'province' => $validated['province'] ?? null,
            'plan_id' => $validated['plan_id'] ?? null,
            'status' => 'trial',
            'trial_ends_at' => now()->addDays(14),
        ]);

        return redirect()->route('tenants.index')->with('success', "Tenant \"{$tenant->name}\" dibuat");
    }

    public function show(Tenant $tenant)
    {
        $tenant->load(['owner', 'plan', 'subscriptions.plan']);

        $invoices = $tenant->invoices()->latest()->paginate(10);

        return Inertia::render('Tenants/Show', compact('tenant', 'invoices'));
    }

    public function update(Request $request, Tenant $tenant)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'nullable|email|max:255',
            'phone' => 'nullable|string|max:30',
            'address' => 'nullable|string',
            'city' => 'nullable|string|max:100',
            'province' => 'nullable|string|max:100',
            'status' => 'required|in:active,inactive,suspended,trial',
            'plan_id' => 'nullable|exists:plans,id',
        ]);

        $tenant->update($validated);

        return back()->with('success', "Tenant \"{$tenant->name}\" diperbarui");
    }

    public function suspend(Tenant $tenant)
    {
        $tenant->update([
            'status' => 'suspended',
            'suspended_at' => now(),
            'suspension_reason' => request('reason', 'Ditangguhkan oleh admin'),
        ]);

        return back()->with('success', "Tenant \"{$tenant->name}\" ditangguhkan");
    }

    public function activate(Tenant $tenant)
    {
        $tenant->update([
            'status' => 'active',
            'suspended_at' => null,
            'suspension_reason' => null,
        ]);

        return back()->with('success', "Tenant \"{$tenant->name}\" diaktifkan");
    }

    public function destroy(Tenant $tenant)
    {
        $tenant->delete();

        return back()->with('success', "Tenant \"{$tenant->name}\" dihapus");
    }
}
