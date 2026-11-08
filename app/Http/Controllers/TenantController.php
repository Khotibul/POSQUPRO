<?php

namespace App\Http\Controllers;

use App\Models\Plan;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Inertia\Inertia;
use Spatie\Permission\Models\Role;

class TenantController extends Controller
{
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
            'owner_name' => 'nullable|string|max:255',
            'owner_email' => 'nullable|email|max:255|unique:users,email',
            'owner_password' => 'nullable|string|min:8',
            'plan_id' => 'nullable|exists:plans,id',
        ]);

        $status = $validated['status'] ?? 'trial';

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

        // Create the tenant admin account (usable on website + desktop Java login)
        $adminMessage = '';
        if (! empty($validated['owner_email'])) {
            $plainPassword = $validated['owner_password'] ?? Str::random(12);
            $hashed = Hash::make($plainPassword);
            $adminData = [
                'name' => $validated['owner_name'] ?: $validated['name'].' Admin',
                'email' => $validated['owner_email'],
                // Pass PLAIN so the model's 'hashed' cast hashes exactly once
                'password' => $plainPassword,
                'password_hash' => $hashed,
                'branch_id' => 1,
                'role' => 'ADMIN',
                'active' => 1,
                'tenant_id' => $tenant->id,
            ];
            if (! Schema::hasColumn('users', 'password')) {
                unset($adminData['password']);
            }
            if (! Schema::hasColumn('users', 'is_active')) {
                unset($adminData['is_active']);
            } else {
                $adminData['is_active'] = true;
            }
            if (! Schema::hasColumn('users', 'tenant_id')) {
                unset($adminData['tenant_id']);
            }
            $admin = User::create($adminData);
            if (class_exists(Role::class)) {
                $admin->assignRole('Admin');
            }
            $tenant->update(['owner_id' => $admin->id]);
            $adminMessage = " Akun admin: {$admin->email} / password: {$plainPassword}";
        }

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
        ]);

        // Slug is never cleared once set; keep the old value when omitted/empty.
        if (array_key_exists('slug', $validated) && $validated['slug'] === null) {
            unset($validated['slug']);
        }

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
