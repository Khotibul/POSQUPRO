<?php

namespace Database\Seeders;

use App\Models\Invoice;
use App\Models\Plan;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class SaaSDataSeeder extends Seeder
{
    public function run(): void
    {
        // Skip if tables don't exist (SQLite tests)
        if (! DB::getSchemaBuilder()->hasTable('plans')) {
            return;
        }

        // ── PLANS ──────────────────────────────────────────────
        $free = Plan::firstOrCreate(['slug' => 'free'], [
            'name' => 'Free',
            'description' => 'Coba gratis selama 14 hari',
            'price' => 0,
            'price_yearly' => 0,
            'trial_days' => 14,
            'max_users' => 1,
            'max_products' => 50,
            'max_branches' => 1,
            'features' => ['pos', 'products'],
            'is_active' => true,
            'sort_order' => 1,
        ]);

        $starter = Plan::firstOrCreate(['slug' => 'starter'], [
            'name' => 'Starter',
            'description' => 'Untuk usaha kecil yang baru mulai',
            'price' => 99000,
            'price_yearly' => 990000,
            'trial_days' => 7,
            'max_users' => 2,
            'max_products' => 200,
            'max_branches' => 1,
            'features' => ['pos', 'products', 'inventory', 'reports'],
            'is_active' => true,
            'sort_order' => 2,
        ]);

        $pro = Plan::firstOrCreate(['slug' => 'pro'], [
            'name' => 'Pro',
            'description' => 'Untuk bisnis yang berkembang',
            'price' => 299000,
            'price_yearly' => 2990000,
            'trial_days' => 7,
            'max_users' => 5,
            'max_products' => 1000,
            'max_branches' => 3,
            'features' => ['pos', 'products', 'inventory', 'reports', 'purchase_orders', 'stock_counts', 'multi_branch'],
            'is_active' => true,
            'sort_order' => 3,
        ]);

        $enterprise = Plan::firstOrCreate(['slug' => 'enterprise'], [
            'name' => 'Enterprise',
            'description' => 'Untuk bisnis berskala besar',
            'price' => 599000,
            'price_yearly' => 5990000,
            'trial_days' => 0,
            'max_users' => 50,
            'max_products' => 10000,
            'max_branches' => 50,
            'features' => ['pos', 'products', 'inventory', 'reports', 'purchase_orders', 'stock_counts', 'multi_branch', 'api_access', 'priority_support'],
            'is_active' => true,
            'sort_order' => 4,
        ]);

        // ── TENANTS ────────────────────────────────────────────
        $owner = User::where('email', 'superadmin@posqupro.test')->first();

        $t1 = Tenant::firstOrCreate(['slug' => 'toko-sejahtera'], [
            'name' => 'Toko Sejahtera',
            'email' => 'sejahtera@example.com',
            'phone' => '08123456789',
            'address' => 'Jl. Merdeka No. 10',
            'city' => 'Jakarta',
            'province' => 'DKI Jakarta',
            'plan_id' => $pro->id,
            'owner_id' => $owner?->id,
            'status' => 'active',
            'is_active' => true,
        ]);

        $t2 = Tenant::firstOrCreate(['slug' => 'minimarket-bahagia'], [
            'name' => 'Minimarket Bahagia',
            'email' => 'bahagia@example.com',
            'phone' => '08567890123',
            'address' => 'Jl. Sudirman No. 25',
            'city' => 'Bandung',
            'province' => 'Jawa Barat',
            'plan_id' => $starter->id,
            'owner_id' => $owner?->id,
            'status' => 'active',
            'is_active' => true,
        ]);

        $t3 = Tenant::firstOrCreate(['slug' => 'warung-mak-mur'], [
            'name' => 'Warung Mak Mur',
            'email' => 'makmur@example.com',
            'phone' => '08789012345',
            'city' => 'Surabaya',
            'province' => 'Jawa Timur',
            'plan_id' => $free->id,
            'owner_id' => $owner?->id,
            'status' => 'trial',
            'trial_ends_at' => now()->addDays(10),
            'is_active' => true,
        ]);

        $t4 = Tenant::firstOrCreate(['slug' => 'elektronik-jaya'], [
            'name' => 'Elektronik Jaya',
            'email' => 'jaya@example.com',
            'phone' => '08901234567',
            'address' => 'Jl. Pahlawan No. 8',
            'city' => 'Yogyakarta',
            'province' => 'DI Yogyakarta',
            'plan_id' => $enterprise->id,
            'owner_id' => $owner?->id,
            'status' => 'active',
            'is_active' => true,
        ]);

        $t5 = Tenant::firstOrCreate(['slug' => 'toko-maju'], [
            'name' => 'Toko Maju Mundur',
            'email' => 'maju@example.com',
            'plan_id' => $starter->id,
            'owner_id' => $owner?->id,
            'status' => 'suspended',
            'suspended_at' => now()->subDays(5),
            'suspension_reason' => 'Pembayaran belum ditransfer',
            'is_active' => true,
        ]);

        // ── INVOICES ───────────────────────────────────────────
        $tenants = [$t1, $t2, $t3, $t4, $t5];
        foreach ($tenants as $t) {
            if (! $t->plan_id) {
                continue;
            }
            $plan = Plan::find($t->plan_id);
            if (! $plan || $plan->price <= 0) {
                continue;
            }

            // Create 2-3 invoices per tenant
            for ($m = 0; $m < 3; $m++) {
                $issuedAt = now()->subMonths($m)->startOfMonth()->addDays(5);
                $tax = round($plan->price * 0.11, 2);
                $isPaid = $m > 0;

                Invoice::firstOrCreate(
                    ['invoice_number' => 'INV-'.$t->slug.'-'.($m + 1)],
                    [
                        'tenant_id' => $t->id,
                        'plan_id' => $plan->id,
                        'status' => $isPaid ? 'paid' : 'pending',
                        'subtotal' => $plan->price,
                        'tax_amount' => $tax,
                        'total' => $plan->price + $tax,
                        'amount_paid' => $isPaid ? $plan->price + $tax : 0,
                        'issued_at' => $issuedAt,
                        'due_at' => $issuedAt->copy()->addDays(7),
                        'paid_at' => $isPaid ? $issuedAt->copy()->addDays(2) : null,
                        'payment_method' => $isPaid ? 'bank_transfer' : null,
                        'items' => [
                            ['description' => "Paket {$plan->name}", 'amount' => $plan->price, 'quantity' => 1],
                        ],
                    ]
                );
            }
        }
    }
}
