<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Create Java POS tables if they don't exist (for SQLite tests + fresh installs)
        if (! Schema::hasTable('sales')) {
            Schema::create('sales', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('branch_id')->nullable();
                $table->unsignedBigInteger('warehouse_id')->nullable();
                $table->unsignedBigInteger('shift_id')->nullable();
                $table->unsignedBigInteger('customer_id')->nullable();
                $table->string('invoice_no', 40)->unique();
                $table->unsignedBigInteger('cashier_id');
                $table->decimal('subtotal', 15, 2);
                $table->decimal('discount', 15, 2)->default(0);
                $table->decimal('tax', 15, 2)->default(0);
                $table->decimal('total', 15, 2);
                $table->decimal('paid', 15, 2);
                $table->decimal('change_amount', 15, 2);
                $table->decimal('donation', 15, 2)->default(0);
                $table->enum('status', ['PAID', 'VOID', 'REFUNDED'])->default('PAID');
                $table->decimal('receivable', 15, 2)->default(0);
                $table->timestamp('created_at')->useCurrent();
            });
        }

        if (! Schema::hasTable('sale_items')) {
            Schema::create('sale_items', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('sale_id');
                $table->unsignedBigInteger('product_id');
                $table->string('sku', 80);
                $table->string('product_name', 180);
                $table->decimal('qty', 15, 2);
                $table->decimal('price', 15, 2);
                $table->decimal('cost', 15, 2)->default(0);
                $table->decimal('discount', 15, 2)->default(0);
                $table->decimal('tax', 15, 2)->default(0);
                $table->decimal('subtotal', 15, 2);
            });
        }

        if (! Schema::hasTable('stock_movements')) {
            Schema::create('stock_movements', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('product_id');
                $table->unsignedBigInteger('warehouse_id')->nullable();
                $table->enum('movement_type', ['SALE', 'RETURN', 'PURCHASE', 'ADJUSTMENT', 'IMPORT', 'TRANSFER_IN', 'TRANSFER_OUT']);
                $table->decimal('qty', 15, 2);
                $table->string('reference_no', 80)->nullable();
                $table->string('note', 255)->nullable();
                $table->timestamp('created_at')->useCurrent();
            });
        }

        if (! Schema::hasTable('shifts')) {
            Schema::create('shifts', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('branch_id');
                $table->unsignedBigInteger('user_id');
                $table->timestamp('opened_at')->nullable();
                $table->timestamp('closed_at')->nullable();
                $table->decimal('opening_cash', 15, 2)->default(0);
                $table->decimal('closing_cash', 15, 2)->default(0);
                $table->decimal('expected_cash', 15, 2)->default(0);
                $table->decimal('total_sales', 15, 2)->default(0);
                $table->decimal('total_expenses', 15, 2)->default(0);
                $table->enum('status', ['OPEN', 'CLOSED'])->default('OPEN');
                $table->timestamp('created_at')->useCurrent();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('sale_items');
        Schema::dropIfExists('sales');
        Schema::dropIfExists('stock_movements');
        Schema::dropIfExists('shifts');
    }
};
