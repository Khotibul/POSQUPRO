<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
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
        $planService = app(\App\Services\PlanService::class);
        if (!$planService->canAddUser()) {
            return response()->json([
                'message' => 'Batas maksimal pengguna tercapai. Upgrade paket Anda.',
                'limits' => $planService->getLimitsSummary(),
            ], 403);
        }

        $data = $request->validate(['name' => ['required', 'string'], 'email' => ['required', 'email', 'unique:users'], 'password' => ['required', 'string', 'min:8'], 'phone' => ['nullable', 'string'], 'is_active' => ['boolean'], 'roles' => ['nullable', 'array'], 'roles.*' => ['exists:roles,name']]);
        $data['password'] = Hash::make($data['password']);
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
