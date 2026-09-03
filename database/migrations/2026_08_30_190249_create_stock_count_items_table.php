<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stock_count_items', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('stock_count_id')->index();
            $table->unsignedBigInteger('product_id')->index();
            $table->integer('system_quantity');
            $table->integer('counted_quantity')->nullable();
            $table->integer('variance')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_count_items');
    }
};
