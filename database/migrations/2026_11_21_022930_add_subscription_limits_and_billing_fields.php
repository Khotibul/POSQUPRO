<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Additive columns for plan quotas, iPaymu billing, and tenant ownership
     * of customer/transaction data. Every change is guarded so the migration
     * is safe on the shared Java desktop schema.
     */
    public function up(): void
    {
        if (Schema::hasTable('plans')) {
            Schema::table('plans', function (Blueprint $table) {
                if (! Schema::hasColumn('plans', 'max_customers')) {
                    $table->unsignedInteger('max_customers')->default(100)->after('max_products');
                }
                if (! Schema::hasColumn('plans', 'max_transactions_per_month')) {
                    $table->unsignedInteger('max_transactions_per_month')->default(1000)->after('max_customers');
                }
            });
        }

        if (Schema::hasTable('invoices')) {
            Schema::table('invoices', function (Blueprint $table) {
                if (! Schema::hasColumn('invoices', 'billing_cycle')) {
                    $table->string('billing_cycle', 20)->default('monthly')->after('status');
                }
                if (! Schema::hasColumn('invoices', 'payment_url')) {
                    $table->string('payment_url', 1000)->nullable()->after('external_id');
                }
            });
        }

        if (Schema::hasTable('customers') && ! Schema::hasColumn('customers', 'tenant_id')) {
            Schema::table('customers', function (Blueprint $table) {
                $table->unsignedBigInteger('tenant_id')->nullable()->index()->after('id');
            });
        }

        if (Schema::hasTable('transactions') && ! Schema::hasColumn('transactions', 'tenant_id')) {
            Schema::table('transactions', function (Blueprint $table) {
                $table->unsignedBigInteger('tenant_id')->nullable()->index()->after('id');
            });
        }

        // A tenant can have many subscriptions over time (trial, renewals,
        // upgrades). The old unique(tenant_id, status) prevented that history.
        if (Schema::hasTable('subscriptions')) {
            try {
                Schema::table('subscriptions', function (Blueprint $table) {
                    $table->dropUnique('sub_active_unique');
                });
            } catch (Throwable) {
                // Index absent or driver does not support dropping it.
            }
        }
    }

    public function down(): void
    {
        foreach (['plans' => ['max_customers', 'max_transactions_per_month'], 'invoices' => ['billing_cycle', 'payment_url'], 'customers' => ['tenant_id'], 'transactions' => ['tenant_id']] as $tableName => $columns) {
            if (! Schema::hasTable($tableName)) {
                continue;
            }

            foreach ($columns as $column) {
                if (Schema::hasColumn($tableName, $column)) {
                    Schema::table($tableName, function (Blueprint $table) use ($column) {
                        $table->dropColumn($column);
                    });
                }
            }
        }
    }
};
