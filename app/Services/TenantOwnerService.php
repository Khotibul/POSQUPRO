<?php

namespace App\Services;

use App\Models\Tenant;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Spatie\Permission\Models\Role;

/**
 * Creates and updates the owner/admin user that belongs to a tenant,
 * mirroring the pos-next-js register-tenant + staff upsert behavior:
 * create always makes an owner user, update keeps that user in sync.
 */
class TenantOwnerService
{
    /**
     * Create the tenant owner/admin account and link it via tenants.owner_id.
     *
     * @param  array{name?: ?string, email: string, password?: ?string}  $owner
     * @return array{0: User, 1: string} user and the plain password (shown once)
     */
    public function create(Tenant $tenant, array $owner): array
    {
        $plainPassword = $owner['password'] ?? Str::random(12);

        $adminData = [
            'name' => $owner['name'] ?? ($tenant->name.' Admin'),
            'email' => $owner['email'],
            // Pass PLAIN so the model's 'hashed' cast hashes exactly once
            'password' => $plainPassword,
            'password_hash' => Hash::make($plainPassword),
            'branch_id' => 1,
            'role' => 'ADMIN',
            'active' => 1,
            'tenant_id' => $tenant->id,
        ];
        if (! Schema::hasColumn('users', 'password')) {
            unset($adminData['password']);
        }
        if (Schema::hasColumn('users', 'is_active')) {
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

        return [$admin, $plainPassword];
    }

    /**
     * Update the tenant's owner user with the provided non-empty fields.
     * Creates the owner first when the tenant has none yet and an email is given.
     * Returns the new plain password when one was set/created, else null.
     *
     * @param  array{name?: ?string, email?: ?string, password?: ?string}  $owner
     */
    public function update(Tenant $tenant, array $owner): ?string
    {
        $fields = array_filter([
            'name' => $owner['name'] ?? null,
            'email' => $owner['email'] ?? null,
            'password' => $owner['password'] ?? null,
        ], fn ($value) => $value !== null && $value !== '');

        if ($fields === []) {
            return null;
        }

        $user = $tenant->owner;
        if ($user === null) {
            if (empty($fields['email'])) {
                return null;
            }
            [, $plainPassword] = $this->create($tenant, [
                'name' => $fields['name'] ?? null,
                'email' => $fields['email'],
                'password' => $fields['password'] ?? null,
            ]);

            return $plainPassword;
        }

        $plainPassword = null;
        if (isset($fields['password'])) {
            $plainPassword = $fields['password'];
            $user->password = $plainPassword;
            if (Schema::hasColumn('users', 'password_hash')) {
                $user->password_hash = Hash::make($plainPassword);
            }
        }
        if (isset($fields['name'])) {
            $user->name = $fields['name'];
        }
        if (isset($fields['email'])) {
            $user->email = $fields['email'];
        }
        $user->save();

        if ($tenant->owner_id !== $user->id) {
            $tenant->update(['owner_id' => $user->id]);
        }
        if (Schema::hasColumn('users', 'tenant_id') && $user->tenant_id !== $tenant->id) {
            $user->forceFill(['tenant_id' => $tenant->id])->save();
        }

        return $plainPassword;
    }
}
