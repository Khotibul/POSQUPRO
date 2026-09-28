<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Create the shared Java/desktop `expenses` table when it does not exist
     * (fresh installs, sqlite tests). Matches the Java Desktop schema exactly.
     */
    public function up(): void
    {
        if (! Schema::hasTable('expenses')) {
            Schema::create('expenses', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('branch_id')->nullable();
                $table->unsignedBigInteger('shift_id')->nullable();
                $table->unsignedBigInteger('user_id');
                $table->string('category', 100);
                $table->string('description', 255)->nullable();
                $table->bigInteger('amount');
                $table->timestamp('created_at')->nullable();
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Intentionally left empty: shared Java table, never drop.
    }
};
