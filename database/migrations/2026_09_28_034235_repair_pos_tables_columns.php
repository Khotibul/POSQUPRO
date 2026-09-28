<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Repair POS-critical tables when the live DB was rebuilt from the Java
     * schema after Laravel migrations already ran (migrations table out of sync).
     * Every column is guarded so this is safe to run on any state.
     * Nullable / defaulted columns only - never breaks the Java desktop app.
     */
    public function up(): void
    {
        if (Schema::hasTable('products')) {
            Schema::table('products', function (Blueprint $table) {
                if (! Schema::hasColumn('products', 'selling_price')) {
                    $table->decimal('selling_price', 15, 2)->nullable()->after('price');
                }
                if (! Schema::hasColumn('products', 'cost_price')) {
                    $table->decimal('cost_price', 15, 2)->nullable()->after('cost');
                }
                if (! Schema::hasColumn('products', 'is_active')) {
                    $table->boolean('is_active')->default(true)->after('active');
                }
                if (! Schema::hasColumn('products', 'image')) {
                    $table->string('image')->nullable()->after('photo');
                }
                if (! Schema::hasColumn('products', 'description')) {
                    $table->text('description')->nullable()->after('name');
                }
                if (! Schema::hasColumn('products', 'tax_id')) {
                    $table->unsignedBigInteger('tax_id')->nullable()->after('category_id');
                }
                if (! Schema::hasColumn('products', 'supplier_id')) {
                    $table->unsignedBigInteger('supplier_id')->nullable()->after('tax_id');
                }
                if (! Schema::hasColumn('products', 'type')) {
                    $table->string('type', 50)->nullable()->after('barcode');
                }
                if (! Schema::hasColumn('products', 'unit_quantity_id')) {
                    $table->unsignedBigInteger('unit_quantity_id')->nullable()->after('unit_id');
                }
                if (! Schema::hasColumn('products', 'tenant_id')) {
                    $table->unsignedBigInteger('tenant_id')->nullable()->after('id');
                    $table->index('tenant_id');
                }
            });

            // Backfill Laravel aliases from Java columns
            DB::table('products')->whereNull('selling_price')->update(['selling_price' => DB::raw('price')]);
            DB::table('products')->whereNull('cost_price')->update(['cost_price' => DB::raw('cost')]);
            DB::table('products')->whereNull('is_active')->update(['is_active' => DB::raw('active')]);
        }

        if (Schema::hasTable('customers')) {
            Schema::table('customers', function (Blueprint $table) {
                if (! Schema::hasColumn('customers', 'is_active')) {
                    $table->boolean('is_active')->default(true)->after('active');
                }
                if (! Schema::hasColumn('customers', 'credit_limit')) {
                    $table->decimal('credit_limit', 12, 2)->default(0)->after('address');
                }
                if (! Schema::hasColumn('customers', 'credit_balance')) {
                    $table->decimal('credit_balance', 12, 2)->default(0)->after('credit_limit');
                }
            });

            DB::table('customers')->whereNull('is_active')->update(['is_active' => DB::raw('active')]);
        }

        if (Schema::hasTable('suppliers')) {
            Schema::table('suppliers', function (Blueprint $table) {
                if (! Schema::hasColumn('suppliers', 'contact_person')) {
                    $table->string('contact_person')->nullable()->after('address');
                }
                if (! Schema::hasColumn('suppliers', 'is_active')) {
                    $table->boolean('is_active')->default(true)->after('contact_person');
                }
            });

            if (Schema::hasColumn('suppliers', 'is_active')) {
                DB::table('suppliers')->whereNull('is_active')->update(['is_active' => DB::raw('active')]);
            }
        }

        if (Schema::hasTable('units')) {
            Schema::table('units', function (Blueprint $table) {
                if (! Schema::hasColumn('units', 'description')) {
                    $table->text('description')->nullable()->after('symbol');
                }
                if (! Schema::hasColumn('units', 'updated_at')) {
                    $table->timestamp('updated_at')->nullable()->after('created_at');
                }
            });
        }

        if (Schema::hasTable('branches')) {
            Schema::table('branches', function (Blueprint $table) {
                if (! Schema::hasColumn('branches', 'is_active')) {
                    $table->boolean('is_active')->default(true)->after('active');
                }
                if (! Schema::hasColumn('branches', 'tenant_id')) {
                    $table->unsignedBigInteger('tenant_id')->nullable()->after('id');
                    $table->index('tenant_id');
                }
            });

            DB::table('branches')->whereNull('is_active')->update(['is_active' => DB::raw('active')]);
        }

        if (Schema::hasTable('warehouses')) {
            Schema::table('warehouses', function (Blueprint $table) {
                if (! Schema::hasColumn('warehouses', 'is_active')) {
                    $table->boolean('is_active')->default(true)->after('active');
                }
                if (! Schema::hasColumn('warehouses', 'tenant_id')) {
                    $table->unsignedBigInteger('tenant_id')->nullable()->after('id');
                    $table->index('tenant_id');
                }
            });

            DB::table('warehouses')->whereNull('is_active')->update(['is_active' => DB::raw('active')]);
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
