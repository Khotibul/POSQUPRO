<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stock_counts', function (Blueprint $table) {
            $table->id();
            $table->string('count_number')->unique();
            $table->unsignedBigInteger('user_id')->index(); // counter
            $table->unsignedBigInteger('approved_by')->nullable()->index();
            $table->enum('status', ['draft', 'counting', 'review', 'approved', 'posted', 'cancelled'])->default('draft');
            $table->boolean('is_blind')->default(false);
            $table->timestamp('counted_at')->nullable();
            $table->timestamp('approved_at')->nullable();
            $table->timestamp('posted_at')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_counts');
    }
};
