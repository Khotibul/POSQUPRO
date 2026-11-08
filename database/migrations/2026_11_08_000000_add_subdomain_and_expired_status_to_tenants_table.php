<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tenants', function (Blueprint $table) {
            $table->string('subdomain')->nullable()->after('domain');
        });

        DB::statement("ALTER TABLE tenants MODIFY status ENUM('active','inactive','suspended','trial','expired') NOT NULL DEFAULT 'trial'");
    }

    public function down(): void
    {
        DB::statement("UPDATE tenants SET status = 'inactive' WHERE status = 'expired'");
        DB::statement("ALTER TABLE tenants MODIFY status ENUM('active','inactive','suspended','trial') NOT NULL DEFAULT 'trial'");

        Schema::table('tenants', function (Blueprint $table) {
            $table->dropColumn('subdomain');
        });
    }
};
