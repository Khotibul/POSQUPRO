<?php

namespace Database\Seeders;

use App\Models\Plan;
use Illuminate\Database\Seeder;

class SubscriptionPlanSeeder extends Seeder
{
    public function run(): void
    {
        $allFeatures = array_keys(Plan::FEATURE_LABELS);

        $plans = [
            [
                'slug' => 'demo',
                'name' => 'Demo 30 Hari',
                'description' => 'Akses penuh seluruh fitur selama 30 hari. Tanpa kartu kredit.',
                'price' => 0,
                'price_yearly' => 0,
                'trial_days' => 30,
                'max_users' => 10,
                'max_products' => 2000,
                'max_customers' => 1000,
                'max_transactions_per_month' => 10000,
                'max_branches' => 5,
                'features' => $allFeatures,
                'sort_order' => 0,
            ],
            [
                'slug' => 'professional',
                'name' => 'Profesional',
                'description' => 'Untuk toko tunggal yang butuh operasional lengkap.',
                'price' => 149000,
                'price_yearly' => 1490000,
                'trial_days' => 0,
                'max_users' => 3,
                'max_products' => 1000,
                'max_customers' => 500,
                'max_transactions_per_month' => 3000,
                'max_branches' => 1,
                'features' => [
                    'pos', 'products', 'customers', 'suppliers', 'inventory',
                    'expenses', 'users', 'reports', 'api_access',
                ],
                'sort_order' => 1,
            ],
            [
                'slug' => 'business',
                'name' => 'Bisnis',
                'description' => 'Untuk bisnis berkembang dengan beberapa cabang.',
                'price' => 349000,
                'price_yearly' => 3490000,
                'trial_days' => 0,
                'max_users' => 10,
                'max_products' => 5000,
                'max_customers' => 3000,
                'max_transactions_per_month' => 15000,
                'max_branches' => 3,
                'features' => [
                    'pos', 'products', 'customers', 'suppliers', 'inventory',
                    'expenses', 'users', 'reports', 'purchase_orders',
                    'stock_counts', 'multi_branch', 'api_access',
                ],
                'sort_order' => 2,
            ],
            [
                'slug' => 'enterprise',
                'name' => 'Enterprise',
                'description' => 'Tanpa batas data, seluruh fitur, dan prioritas dukungan.',
                'price' => 749000,
                'price_yearly' => 7490000,
                'trial_days' => 0,
                'max_users' => 0,
                'max_products' => 0,
                'max_customers' => 0,
                'max_transactions_per_month' => 0,
                'max_branches' => 0,
                'features' => $allFeatures,
                'sort_order' => 3,
            ],
        ];

        foreach ($plans as $attributes) {
            Plan::updateOrCreate(
                ['slug' => $attributes['slug']],
                array_merge($attributes, [
                    'currency' => 'IDR',
                    'billing_cycle' => 30,
                    'is_active' => true,
                ]),
            );
        }

        // Old plans remain attached to existing tenants but are no longer sold.
        Plan::whereIn('slug', ['free', 'starter', 'pro'])->update(['is_active' => false]);
    }
}
