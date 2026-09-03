<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('payments')) {
            Schema::create('payments', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('transaction_id')->index();
                $table->decimal('amount', 15, 2);
                $table->enum('method', ['cash', 'card', 'qris', 'transfer'])->default('cash');
                $table->enum('status', ['pending', 'success', 'failed'])->default('success');
                $table->timestamp('paid_at')->nullable();
                $table->text('notes')->nullable();
                $table->timestamps();
            });
        } else {
            // Java payments exists (sale_id, method varchar, amount, reference_no) - add Laravel columns
            Schema::table('payments', function (Blueprint $table) {
                if (! Schema::hasColumn('payments', 'transaction_id')) {
                    $table->unsignedBigInteger('transaction_id')->nullable()->index()->after('id');
                }
                if (! Schema::hasColumn('payments', 'status')) {
                    $table->enum('status', ['pending', 'success', 'failed'])->default('success')->after('method');
                }
                if (! Schema::hasColumn('payments', 'paid_at')) {
                    $table->timestamp('paid_at')->nullable()->after('status');
                }
                if (! Schema::hasColumn('payments', 'notes')) {
                    $table->text('notes')->nullable()->after('paid_at');
                }
                if (! Schema::hasColumn('payments', 'updated_at')) {
                    $table->timestamp('updated_at')->nullable()->after('created_at');
                }
                // Ensure method is enum compatible - Java has varchar, keep it
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('payments');
    }
};
