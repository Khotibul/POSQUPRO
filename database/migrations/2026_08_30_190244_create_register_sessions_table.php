<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('register_sessions', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('register_id')->index();
            $table->unsignedBigInteger('user_id')->index(); // cashier
            $table->unsignedBigInteger('opened_by')->nullable()->index(); // manager who opened
            $table->unsignedBigInteger('closed_by')->nullable()->index();
            $table->decimal('opening_float', 15, 2)->default(0);
            $table->decimal('expected_cash', 15, 2)->nullable();
            $table->decimal('actual_cash', 15, 2)->nullable();
            $table->decimal('over_short', 15, 2)->nullable();
            $table->enum('status', ['open', 'closed', 'reopened'])->default('open');
            $table->timestamp('opened_at');
            $table->timestamp('closed_at')->nullable();
            $table->text('notes')->nullable();
            $table->text('close_notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('register_sessions');
    }
};
