<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\PlanService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;

class UserController extends Controller
{
    public function index()
    {
        return User::with('roles')->latest()->paginate(15);
    }

    public function store(Request $request)
    {
        // Check plan limit
        $planService = app(PlanService::class);
        if (! $planService->canAddUser()) {
            return response()->json([
                'message' => 'Batas maksimal pengguna tercapai. Upgrade paket Anda.',
                'limits' => $planService->getLimitsSummary(),
            ], 403);
        }

        $data = $request->validate(['name' => ['required', 'string'], 'email' => ['required', 'email', 'unique:users'], 'password' => ['required', 'string', 'min:8'], 'phone' => ['nullable', 'string'], 'is_active' => ['boolean'], 'roles' => ['nullable', 'array'], 'roles.*' => ['exists:roles,name']]);
        // NOTE: pass the PLAIN password so the User model's 'hashed' cast hashes it exactly once.
        $plainPassword = $data['password'];
        $hashed = Hash::make($plainPassword);
        // Only write columns that exist (bare Java schema has no password/phone/is_active)
        if (! Schema::hasColumn('users', 'password')) {
            unset($data['password']);
        }
        $data['password_hash'] = $hashed;
        // Map Laravel role to Java enum for desktop compatibility
        $primaryRole = $data['roles'][0] ?? null;
        $javaRole = match ($primaryRole) {
            'Super Admin' => 'OWNER',
            'Admin' => 'ADMIN',
            'Finance' => 'ADMIN',
            'Warehouse Manager' => 'MANAGER',
            'Cashier' => 'CASHIER',
            default => 'CASHIER',
        };
        $data['role'] = $javaRole;
        $data['active'] = $data['is_active'] ?? 1;
        if (! Schema::hasColumn('users', 'is_active')) {
            unset($data['is_active']);
        } else {
            $data['is_active'] = $data['is_active'] ?? true;
        }
        if (! Schema::hasColumn('users', 'phone')) {
            unset($data['phone']);
        }
        $data['branch_id'] = $data['branch_id'] ?? 1;
        $user = User::create(collect($data)->except('roles')->toArray());
        if (! empty($data['roles'])) {
            $user->syncRoles($data['roles']);
        }

        return $user->load('roles');
    }

    public function show(User $user)
    {
        return $user->load('roles');
    }

    public function update(Request $request, User $user)
    {
        $data = $request->validate(['name' => ['sometimes', 'string'], 'email' => ['sometimes', 'email', 'unique:users,email,'.$user->id], 'phone' => ['nullable', 'string'], 'is_active' => ['boolean'], 'roles' => ['nullable', 'array'], 'roles.*' => ['exists:roles,name']]);
        if (! Schema::hasColumn('users', 'phone')) {
            unset($data['phone']);
        }
        if (! Schema::hasColumn('users', 'is_active')) {
            unset($data['is_active']);
        }
        $user->update(collect($data)->except('roles')->toArray());
        if (isset($data['roles'])) {
            $user->syncRoles($data['roles']);
        }

        return $user->load('roles');
    }

    public function destroy(User $user)
    {
        $user->delete();

        return response()->json(['message' => 'deleted']);
    }
}
