<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Spatie\Permission\Models\Role;

class TenantController extends Controller
{
    public function index(Request $request)
    {
        $tenants = Tenant::with(['owner', 'plan'])
            ->when($request->search, fn ($q, $s) => $q->where('name', 'like', "%{$s}%")->orWhere('email', 'like', "%{$s}%"))
            ->when($request->status, fn ($q, $s) => $q->where('status', $s))
            ->when($request->plan_id, fn ($q, $p) => $q->where('plan_id', $p))
            ->latest()
            ->paginate(15);

        return $tenants;
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
            'owner_email' => 'nullable|email|max:255|unique:users,email',
            'owner_password' => 'nullable|string|min:8',
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

        $plainPassword = null;
        if (! empty($validated['owner_email'])) {
            $plainPassword = $validated['owner_password'] ?? Str::random(12);
            $hashed = Hash::make($plainPassword);
            $adminData = [
                'name' => $validated['owner_name'] ?: $validated['name'].' Admin',
                'email' => $validated['owner_email'],
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
            if (class_exists(Role::class) && Role::where('name', 'Admin')->exists()) {
                $admin->assignRole('Admin');
            }
            $tenant->update(['owner_id' => $admin->id]);
        }

        return response()->json([
            'tenant' => $tenant->load(['owner', 'plan']),
            'owner_password' => $plainPassword,
        ], 201);
    }

    public function show(Tenant $tenant)
    {
        $tenant->load(['owner', 'plan', 'subscriptions.plan']);

        return response()->json([
            'tenant' => $tenant,
            'invoices' => $tenant->invoices()->latest()->limit(20)->get(),
        ]);
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

        return $tenant->load(['owner', 'plan']);
    }

    public function suspend(Tenant $tenant)
    {
        $tenant->update([
            'status' => 'suspended',
            'suspended_at' => now(),
            'suspension_reason' => request('reason', 'Ditangguhkan oleh admin'),
        ]);

        return $tenant;
    }

    public function activate(Tenant $tenant)
    {
        $tenant->update([
            'status' => 'active',
            'suspended_at' => null,
            'suspension_reason' => null,
        ]);

        return $tenant;
    }

    public function destroy(Tenant $tenant)
    {
        $tenant->delete();

        return response()->json(['message' => 'deleted']);
    }
}
