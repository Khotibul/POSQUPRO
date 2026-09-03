<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('unit_quantities', function (Blueprint $table) {
            $table->id();
            $table->string('name'); // e.g. Kilogram, Piece, Liter
            $table->string('symbol')->unique(); // kg, pcs, l
            $table->text('description')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('unit_quantities');
    }
};
