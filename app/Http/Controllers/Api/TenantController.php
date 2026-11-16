<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Tenant;
use App\Services\TenantOwnerService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class TenantController extends Controller
{
    public function __construct(private TenantOwnerService $ownerService) {}

    public function index(Request $request)
    {
        $tenants = Tenant::with(['owner', 'plan'])
            ->withCount(['users', 'branches'])
            ->when($request->search, fn ($q, $s) => $q->where(function ($w) use ($s) {
                $w->where('name', 'like', "%{$s}%")
                    ->orWhere('slug', 'like', "%{$s}%")
                    ->orWhere('domain', 'like', "%{$s}%")
                    ->orWhere('subdomain', 'like', "%{$s}%")
                    ->orWhere('email', 'like', "%{$s}%");
            }))
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

            return [$tenant, $plainPassword];
        });

        $data = $tenant->load(['owner', 'plan'])->toArray();
        $data['owner_password'] = $plainPassword;

        return response()->json($data, 201);
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

        if (array_key_exists('slug', $validated) && $validated['slug'] === null) {
            unset($validated['slug']);
        }

        $plainPassword = null;
        DB::transaction(function () use ($request, $tenant, $validated, &$plainPassword) {
            $tenantFields = collect($validated)->except(['owner_name', 'owner_email', 'owner_password'])->all();
            $tenant->update($tenantFields);

            $plainPassword = $this->ownerService->update($tenant, [
                'name' => $request->input('owner_name'),
                'email' => $request->input('owner_email'),
                'password' => $request->input('owner_password'),
            ]);
        });

        $data = $tenant->load(['owner', 'plan'])->toArray();
        $data['owner_password'] = $plainPassword;

        return response()->json($data);
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
