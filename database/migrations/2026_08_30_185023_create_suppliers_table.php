<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('suppliers')) {
            Schema::create('suppliers', function (Blueprint $table) {
                $table->id();
                $table->string('code')->unique()->nullable();
                $table->string('name');
                $table->string('email')->nullable();
                $table->string('phone')->nullable();
                $table->text('address')->nullable();
                $table->string('contact_person')->nullable();
                $table->boolean('is_active')->default(true);
                $table->boolean('active')->default(true);
                $table->timestamps();
            });
        } else {
            Schema::table('suppliers', function (Blueprint $table) {
                if (! Schema::hasColumn('suppliers', 'contact_person')) {
                    $table->string('contact_person')->nullable()->after('address');
                }
                if (! Schema::hasColumn('suppliers', 'is_active') && Schema::hasColumn('suppliers', 'active')) {
                    $table->boolean('is_active')->default(true)->after('contact_person');
                } elseif (! Schema::hasColumn('suppliers', 'is_active')) {
                    $table->boolean('is_active')->default(true)->after('contact_person');
                }
                if (! Schema::hasColumn('suppliers', 'updated_at')) {
                    $table->timestamp('updated_at')->nullable()->after('created_at');
                }
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('suppliers');
    }
};
