<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('customers')) {
            Schema::create('customers', function (Blueprint $table) {
                $table->id();
                $table->string('code')->unique()->nullable();
                $table->string('name');
                $table->string('email')->nullable();
                $table->string('phone')->nullable();
                $table->text('address')->nullable();
                $table->decimal('credit_limit', 15, 2)->default(0);
                $table->decimal('credit_balance', 15, 2)->default(0);
                $table->boolean('is_active')->default(true);
                $table->boolean('active')->default(true);
                $table->timestamps();
            });
        } else {
            Schema::table('customers', function (Blueprint $table) {
                if (! Schema::hasColumn('customers', 'credit_limit')) {
                    $table->decimal('credit_limit', 15, 2)->default(0)->after('address');
                }
                if (! Schema::hasColumn('customers', 'credit_balance')) {
                    $table->decimal('credit_balance', 15, 2)->default(0)->after('credit_limit');
                }
                if (! Schema::hasColumn('customers', 'is_active') && Schema::hasColumn('customers', 'active')) {
                    $table->boolean('is_active')->default(true)->after('credit_balance');
                } elseif (! Schema::hasColumn('customers', 'is_active')) {
                    $table->boolean('is_active')->default(true)->after('credit_balance');
                }
                if (! Schema::hasColumn('customers', 'code')) {
                    // Keep Java code column if not exists, else nothing
                }
                if (! Schema::hasColumn('customers', 'updated_at')) {
                    $table->timestamp('updated_at')->nullable()->after('created_at');
                }
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('customers');
    }
};
