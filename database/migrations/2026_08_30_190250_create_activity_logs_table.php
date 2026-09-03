<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('activity_logs', function (Blueprint $table) {
            $table->id();
            $table->nullableMorphs('subject'); // model that was changed
            $table->unsignedBigInteger('user_id')->nullable()->index();
            $table->string('event'); // created, updated, deleted, login, logout, sale, purchase, etc
            $table->string('description')->nullable();
            $table->json('properties')->nullable(); // old/new values
            $table->ipAddress('ip_address')->nullable();
            $table->text('user_agent')->nullable();
            $table->timestamp('created_at')->useCurrent();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('activity_logs');
    }
};
