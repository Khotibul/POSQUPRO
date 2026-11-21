<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * The legacy unique(tenant_id, status) index blocks renewal history and
     * is also the index MySQL uses for the tenant foreign key. Add a normal
     * tenant_id index first, then drop the unique index.
     */
    public function up(): void
    {
        if (! Schema::hasTable('subscriptions')) {
            return;
        }

        $indexes = collect(Schema::getIndexes('subscriptions'))->pluck('name');

        if (! $indexes->contains('subscriptions_tenant_id_index')) {
            Schema::table('subscriptions', function (Blueprint $table) {
                $table->index('tenant_id', 'subscriptions_tenant_id_index');
            });
        }

        if ($indexes->contains('sub_active_unique')) {
            try {
                Schema::table('subscriptions', function (Blueprint $table) {
                    $table->dropUnique('sub_active_unique');
                });
            } catch (Throwable) {
                // Keep working with one subscription row per tenant.
            }
        }
    }

    public function down(): void
    {
        // Intentionally left empty: dropping the unique index is a repair.
    }
};
