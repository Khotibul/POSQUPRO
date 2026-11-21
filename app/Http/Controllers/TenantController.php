<?php

namespace App\Http\Controllers;

use App\Models\Plan;
use App\Models\Tenant;
use App\Services\SubscriptionService;
use App\Services\TenantOwnerService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;

class TenantController extends Controller
{
    public function __construct(private TenantOwnerService $ownerService) {}

    public function index(Request $request)
    {
        $q = trim((string) ($request->q ?? $request->search ?? ''));

        $tenants = Tenant::with(['owner', 'plan'])
            ->withCount(['users', 'branches'])
            ->when($q !== '', fn ($query) => $query->where(function ($w) use ($q) {
                $w->where('name', 'like', "%{$q}%")
                    ->orWhere('slug', 'like', "%{$q}%")
                    ->orWhere('domain', 'like', "%{$q}%")
                    ->orWhere('subdomain', 'like', "%{$q}%")
                    ->orWhere('email', 'like', "%{$q}%");
            }))
            ->when($request->status, fn ($query, $s) => $query->where('status', $s))
            ->when($request->plan_id, fn ($query, $p) => $query->where('plan_id', $p))
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
            'expired' => Tenant::where('status', 'expired')->count(),
            'revenue' => DB::table('invoices')->where('status', 'paid')->sum('total'),
        ];

        return Inertia::render('Tenants/Index', compact('tenants', 'plans', 'stats'));
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'slug' => 'nullable|string|max:80|unique:tenants,slug',
            'domain' => ['nullable', 'string', 'max:255', 'regex:/^[a-z0-9.-]+\.[a-z]{2,}$/i', 'unique:tenants,domain'],
            'subdomain' => ['nullable', 'string', 'max:63', 'regex:/^[a-z0-9-]+$/i', 'unique:tenants,subdomain'],
            'status' => 'nullable|in:active,inactive,suspended,trial,expired',
            'trial_ends_at' => 'nullable|date',
            'suspended_at' => 'nullable|date',
            'email' => 'nullable|email|max:255',
            'phone' => 'nullable|string|max:30',
            'address' => 'nullable|string',
            'city' => 'nullable|string|max:100',
            'province' => 'nullable|string|max:100',
            'owner_name' => 'required|string|max:255',
            'owner_email' => 'required|email|max:255|unique:users,email',
            'owner_password' => 'nullable|string|min:8',
            'plan_id' => 'nullable|exists:plans,id',
        ]);

        $status = $validated['status'] ?? 'trial';

        [$tenant, $plainPassword] = DB::transaction(function () use ($validated, $status) {
            $tenant = Tenant::create([
                'name' => $validated['name'],
                'slug' => $validated['slug'] ?? null,
                'domain' => $validated['domain'] ?? null,
                'subdomain' => $validated['subdomain'] ?? null,
                'email' => $validated['email'] ?? $validated['owner_email'] ?? null,
                'phone' => $validated['phone'] ?? null,
                'address' => $validated['address'] ?? null,
                'city' => $validated['city'] ?? null,
                'province' => $validated['province'] ?? null,
                'plan_id' => $validated['plan_id'] ?? null,
                'status' => $status,
                'trial_ends_at' => $validated['trial_ends_at'] ?? ($status === 'trial' ? now()->addDays(14) : null),
                'suspended_at' => $validated['suspended_at'] ?? null,
            ]);

            [, $plainPassword] = $this->ownerService->create($tenant, [
                'name' => $validated['owner_name'],
                'email' => $validated['owner_email'],
                'password' => $validated['owner_password'] ?? null,
            ]);

            if ($status === 'trial') {
                $trialPlan = ! empty($validated['plan_id']) ? Plan::find($validated['plan_id']) : null;
                app(SubscriptionService::class)->startTrial($tenant, null, $trialPlan);
            }

            return [$tenant, $plainPassword];
        });

        $adminMessage = " Akun admin: {$validated['owner_email']} / password: {$plainPassword}";

        return redirect()->route('tenants.index')->with('success', "Tenant \"{$tenant->name}\" dibuat.{$adminMessage}");
    }

    public function show(Tenant $tenant)
    {
        $tenant->load(['owner', 'plan', 'subscriptions.plan']);

        $invoices = $tenant->invoices()->latest()->paginate(10);

        $plans = Plan::where('is_active', true)->orderBy('sort_order')->get();

        return Inertia::render('Tenants/Show', compact('tenant', 'invoices', 'plans'));
    }

    public function update(Request $request, Tenant $tenant)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'slug' => 'sometimes|nullable|string|max:80|unique:tenants,slug,'.$tenant->id,
            'domain' => ['sometimes', 'nullable', 'string', 'max:255', 'regex:/^[a-z0-9.-]+\.[a-z]{2,}$/i', 'unique:tenants,domain,'.$tenant->id],
            'subdomain' => ['sometimes', 'nullable', 'string', 'max:63', 'regex:/^[a-z0-9-]+$/i', 'unique:tenants,subdomain,'.$tenant->id],
            'email' => 'nullable|email|max:255',
            'phone' => 'nullable|string|max:30',
            'address' => 'nullable|string',
            'city' => 'nullable|string|max:100',
            'province' => 'nullable|string|max:100',
            'status' => 'required|in:active,inactive,suspended,trial,expired',
            'trial_ends_at' => 'nullable|date',
            'suspended_at' => 'nullable|date',
            'plan_id' => 'nullable|exists:plans,id',
            'owner_name' => 'sometimes|nullable|string|max:255',
            'owner_email' => 'sometimes|nullable|email|max:255|unique:users,email,'.($tenant->owner_id ?? 0),
            'owner_password' => 'sometimes|nullable|string|min:8',
        ]);

        // Slug is never cleared once set; keep the old value when omitted/empty.
        if (array_key_exists('slug', $validated) && $validated['slug'] === null) {
            unset($validated['slug']);
        }

        $ownerPassword = null;
        DB::transaction(function () use ($request, $tenant, $validated, &$ownerPassword) {
            $tenantFields = collect($validated)->except(['owner_name', 'owner_email', 'owner_password'])->all();
            $tenant->update($tenantFields);

            $ownerPassword = $this->ownerService->update($tenant, [
                'name' => $request->input('owner_name'),
                'email' => $request->input('owner_email'),
                'password' => $request->input('owner_password'),
            ]);
        });

        if ($tenant->status === 'active' && app(SubscriptionService::class)->isExpired($tenant)) {
            app(SubscriptionService::class)->reactivate($tenant);
        }

        $message = "Tenant \"{$tenant->name}\" diperbarui";
        if ($ownerPassword !== null) {
            $message .= ". Password akun owner: {$ownerPassword}";
        }

        return back()->with('success', $message);
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
        app(SubscriptionService::class)->reactivate($tenant);

        return back()->with('success', "Tenant \"{$tenant->name}\" diaktifkan dengan masa aktif 30 hari");
    }

    public function destroy(Tenant $tenant)
    {
        $tenant->delete();

        return back()->with('success', "Tenant \"{$tenant->name}\" dihapus");
    }
}
