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
        $this->call(SubscriptionPlanSeeder::class);

        $demo = Plan::where('slug', 'demo')->firstOrFail();
        $professional = Plan::where('slug', 'professional')->firstOrFail();
        $business = Plan::where('slug', 'business')->firstOrFail();
        $enterprise = Plan::where('slug', 'enterprise')->firstOrFail();

        // ── TENANTS ────────────────────────────────────────────
        $owner = User::where('email', 'superadmin@posqupro.test')->first();

        $t1 = Tenant::firstOrCreate(['slug' => 'toko-sejahtera'], [
            'name' => 'Toko Sejahtera',
            'email' => 'sejahtera@example.com',
            'phone' => '08123456789',
            'address' => 'Jl. Merdeka No. 10',
            'city' => 'Jakarta',
            'province' => 'DKI Jakarta',
            'plan_id' => $business->id,
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
            'plan_id' => $professional->id,
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
            'plan_id' => $demo->id,
            'owner_id' => $owner?->id,
            'status' => 'trial',
            'trial_ends_at' => now()->addDays(30),
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
            'plan_id' => $professional->id,
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
