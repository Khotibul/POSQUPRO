<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\PlanService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

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
        $hashed = Hash::make($data['password']);
        $data['password'] = $hashed;
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
        $data['is_active'] = $data['is_active'] ?? true;
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
