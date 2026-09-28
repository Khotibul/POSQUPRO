<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Repair users table when the live DB was rebuilt from the Java schema
     * after Laravel migrations already ran (migrations table out of sync).
     * Every column is guarded so this is safe to run on any state.
     */
    public function up(): void
    {
        if (! Schema::hasTable('users')) {
            return;
        }

        Schema::table('users', function (Blueprint $table) {
            if (! Schema::hasColumn('users', 'tenant_id')) {
                $table->unsignedBigInteger('tenant_id')->nullable()->after('id');
                $table->index('tenant_id');
            }
            if (! Schema::hasColumn('users', 'google_id')) {
                $table->string('google_id')->nullable()->after('id');
                $table->index('google_id');
            }
            if (! Schema::hasColumn('users', 'phone')) {
                $table->string('phone')->nullable()->after('email');
            }
            if (! Schema::hasColumn('users', 'avatar')) {
                $table->string('avatar')->nullable()->after('email');
            }
            if (! Schema::hasColumn('users', 'password')) {
                $table->string('password')->nullable()->after('avatar');
            }
            if (! Schema::hasColumn('users', 'is_active')) {
                $table->boolean('is_active')->default(true)->after('phone');
            }
            if (! Schema::hasColumn('users', 'last_login_at')) {
                $table->timestamp('last_login_at')->nullable()->after('is_active');
            }
            if (! Schema::hasColumn('users', 'email_verified_at')) {
                $table->timestamp('email_verified_at')->nullable()->after('email');
            }
            if (! Schema::hasColumn('users', 'remember_token')) {
                $table->rememberToken()->after('password');
            }
        });

        // Backfill: dual-flag Java/Laravel columns must agree
        if (Schema::hasColumn('users', 'is_active')) {
            DB::table('users')->whereNull('is_active')->update(['is_active' => DB::raw('active')]);
        }
        if (Schema::hasColumn('users', 'password')) {
            DB::table('users')
                ->whereNull('password')
                ->whereNotNull('password_hash')
                ->update(['password' => DB::raw('password_hash')]);
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Intentionally left empty: never drop shared Java/Laravel columns.
    }
};
