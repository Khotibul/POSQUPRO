<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (! Schema::hasColumn('users', 'phone')) {
                $table->string('phone')->nullable()->after('email');
            }
            if (! Schema::hasColumn('users', 'is_active') && ! Schema::hasColumn('users', 'active')) {
                $table->boolean('is_active')->default(true)->after('phone');
            } elseif (! Schema::hasColumn('users', 'is_active')) {
                // Java has 'active', add is_active as alias
                $table->boolean('is_active')->default(true)->after('active');
            }
            if (! Schema::hasColumn('users', 'last_login_at')) {
                $table->timestamp('last_login_at')->nullable()->after('is_active');
            }
            // Laravel needs password column, Java has password_hash - ensure both exist for dual compatibility
            if (! Schema::hasColumn('users', 'password') && Schema::hasColumn('users', 'password_hash')) {
                $table->string('password')->nullable()->after('email_verified_at');
            }
            if (! Schema::hasColumn('users', 'password_hash')) {
                $table->string('password_hash')->nullable()->after('password');
            }
            if (! Schema::hasColumn('users', 'branch_id')) {
                $table->unsignedBigInteger('branch_id')->nullable()->after('password_hash');
            }
            if (! Schema::hasColumn('users', 'role')) {
                $table->string('role')->default('CASHIER')->after('branch_id');
            }
            if (! Schema::hasColumn('users', 'active') && Schema::hasColumn('users', 'is_active')) {
                $table->boolean('active')->default(true)->after('role');
            } elseif (! Schema::hasColumn('users', 'active') && ! Schema::hasColumn('users', 'is_active')) {
                $table->boolean('active')->default(true)->after('role');
            }
            if (! Schema::hasColumn('users', 'email_verified_at')) {
                $table->timestamp('email_verified_at')->nullable()->after('email');
            }
            if (! Schema::hasColumn('users', 'remember_token')) {
                $table->rememberToken()->after('password');
            }
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['phone', 'is_active', 'last_login_at']);
        });
    }
};
