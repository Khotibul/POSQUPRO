<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Create core Java/desktop tables when they are completely missing
     * (production DBs that were never initialized with the Java schema).
     * Matches the Java schema exactly + Laravel alias columns, then seeds
     * minimal defaults (branch, warehouse, units) so POS works immediately.
     */
    public function up(): void
    {
        if (! Schema::hasTable('branches')) {
            Schema::create('branches', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('tenant_id')->nullable()->index();
                $table->string('code', 40)->unique();
                $table->string('name', 160);
                $table->text('address')->nullable();
                $table->string('phone', 40)->nullable();
                $table->boolean('active')->default(true);
                $table->boolean('is_active')->default(true);
                $table->timestamp('created_at')->useCurrent();
                $table->timestamp('updated_at')->useCurrent()->useCurrentOnUpdate();
            });
        }

        if (! Schema::hasTable('warehouses')) {
            Schema::create('warehouses', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('tenant_id')->nullable()->index();
                $table->unsignedBigInteger('branch_id');
                $table->string('code', 40)->unique();
                $table->string('name', 160);
                $table->string('phone', 40)->nullable();
                $table->text('address')->nullable();
                $table->boolean('active')->default(true);
                $table->boolean('is_active')->default(true);
                $table->timestamp('created_at')->useCurrent();
                $table->timestamp('updated_at')->useCurrent()->useCurrentOnUpdate();
            });
        }

        if (! Schema::hasTable('units')) {
            Schema::create('units', function (Blueprint $table) {
                $table->id();
                $table->string('name', 80);
                $table->string('symbol', 20)->unique();
                $table->text('description')->nullable();
                $table->timestamp('created_at')->useCurrent();
                $table->timestamp('updated_at')->nullable();
            });
        }

        // Minimal defaults so POS/checkout works out of the box
        if (Schema::hasTable('branches') && DB::table('branches')->count() === 0) {
            $branchId = DB::table('branches')->insertGetId([
                'code' => 'TKO-001',
                'name' => 'Toko Utama',
                'active' => true,
                'is_active' => true,
            ]);
            if (Schema::hasTable('warehouses') && DB::table('warehouses')->count() === 0) {
                DB::table('warehouses')->insert([
                    'branch_id' => $branchId,
                    'code' => 'GDG-001',
                    'name' => 'Gudang Utama',
                    'active' => true,
                    'is_active' => true,
                ]);
            }
        }

        if (Schema::hasTable('units') && DB::table('units')->count() === 0) {
            foreach ([['Pcs', 'pcs'], ['Kilogram', 'kg'], ['Gram', 'g'], ['Liter', 'ltr'], ['Pack', 'pack'], ['Dus', 'dus'], ['Meter', 'm'], ['Lusin', 'lsn']] as [$name, $symbol]) {
                DB::table('units')->insert(['name' => $name, 'symbol' => $symbol]);
            }
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Intentionally left empty: shared Java tables, never drop.
    }
};
