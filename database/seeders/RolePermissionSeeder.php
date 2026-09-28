<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class RolePermissionSeeder extends Seeder
{
    public function run(): void
    {
        $permissions = [
            'users.view', 'users.create', 'users.edit', 'users.delete',
            'customers.view', 'customers.create', 'customers.edit', 'customers.delete',
            'suppliers.view', 'suppliers.create', 'suppliers.edit', 'suppliers.delete',
            'categories.view', 'categories.manage',
            'unit-quantities.view', 'unit-quantities.manage',
            'taxes.view', 'taxes.manage',
            'products.view', 'products.create', 'products.edit', 'products.delete',
            'inventory.view', 'inventory.manage',
            'transactions.view', 'transactions.create', 'transactions.delete',
            'payments.view', 'payments.manage',
            'reports.view', 'finance.view',
            'expenses.view', 'expenses.create', 'expenses.edit', 'expenses.delete',
            'pos.access',
            // SaaS permissions
            'tenants.view', 'tenants.create', 'tenants.edit', 'tenants.delete', 'tenants.manage',
            'plans.view', 'plans.manage',
            'invoices.view', 'invoices.create', 'invoices.manage',
            'billing.view', 'billing.manage',
        ];

        foreach ($permissions as $permission) {
            Permission::firstOrCreate(['name' => $permission]);
        }

        // 5 roles mirip pos-next-js
        $superAdmin = Role::firstOrCreate(['name' => 'Super Admin']);
        $admin = Role::firstOrCreate(['name' => 'Admin']);
        $warehouseManager = Role::firstOrCreate(['name' => 'Warehouse Manager']);
        $cashier = Role::firstOrCreate(['name' => 'Cashier']);
        $finance = Role::firstOrCreate(['name' => 'Finance']);

        $superAdmin->syncPermissions(Permission::all());
        $admin->syncPermissions(Permission::all());
        // Additive (safe on re-run): expenses for Finance
        $finance->givePermissionTo(['expenses.view', 'expenses.create', 'expenses.edit']);

        $warehouseManager->syncPermissions([
            'products.view', 'products.create', 'products.edit',
            'inventory.view', 'inventory.manage',
            'categories.view', 'unit-quantities.view',
            'suppliers.view', 'transactions.view',
        ]);

        $cashier->syncPermissions([
            'pos.access', 'products.view', 'customers.view', 'customers.create',
            'transactions.view', 'transactions.create', 'payments.view',
        ]);

        $finance->syncPermissions([
            'transactions.view', 'payments.view', 'payments.manage',
            'reports.view', 'finance.view', 'customers.view', 'suppliers.view',
        ]);

        // Create default users
        $this->createUser('Super Admin', 'superadmin@posqupro.test', 'password', 'Super Admin');
        $this->createUser('Admin', 'admin@posqupro.test', 'password', 'Admin');
        $this->createUser('Warehouse', 'warehouse@posqupro.test', 'password', 'Warehouse Manager');
        $this->createUser('Cashier', 'cashier@posqupro.test', 'password', 'Cashier');
        $this->createUser('Finance', 'finance@posqupro.test', 'password', 'Finance');
    }

    private function createUser(string $name, string $email, string $password, string $role): void
    {
        $hashed = Hash::make($password);
        // Map Laravel role to Java role enum
        $javaRole = match ($role) {
            'Super Admin' => 'OWNER',
            'Admin' => 'ADMIN',
            'Warehouse Manager' => 'MANAGER',
            'Cashier' => 'CASHIER',
            'Finance' => 'ADMIN',
            default => 'CASHIER',
        };

        // Check if user exists
        $existing = User::where('email', $email)->first();
        if ($existing) {
            // Update missing fields for Java compatibility (only columns that exist)
            $updates = array_filter([
                'password_hash' => $hashed,
                'branch_id' => $existing->branch_id ?? 1,
                'role' => $existing->role ?? $javaRole,
                'active' => 1,
            ]);
            if (Schema::hasColumn('users', 'is_active')) {
                $updates['is_active'] = 1;
            }
            if (Schema::hasColumn('users', 'password') && empty($existing->password)) {
                // Query builder bypasses the 'hashed' cast: store pre-hashed value
                $updates['password'] = $hashed;
            }
            DB::table('users')->where('id', $existing->id)->update($updates);
            $existing->assignRole($role);

            return;
        }

        // Create new user with both Laravel and Java fields (only columns that exist).
        // NOTE: pass PLAIN password so the model's 'hashed' cast hashes it exactly once.
        $createData = [
            'name' => $name,
            'email' => $email,
            'password' => $password,
            'password_hash' => $hashed,
            'branch_id' => 1,
            'role' => $javaRole,
            'active' => 1,
        ];
        if (Schema::hasColumn('users', 'is_active')) {
            $createData['is_active'] = true;
        }
        if (! Schema::hasColumn('users', 'password')) {
            unset($createData['password']);
        }
        $user = User::create($createData);
        $user->assignRole($role);
    }
}
