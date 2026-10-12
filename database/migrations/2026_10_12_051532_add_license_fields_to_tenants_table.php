<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    /**
     * License/API credentials per tenant so posqupro-desktop can activate
     * against this Laravel app (like POS-NEXT-JS tenant licensing).
     * Guarded + backfills existing tenants. No destructive operations.
     */
    public function up(): void
    {
        if (! Schema::hasTable('tenants')) {
            return;
        }

        Schema::table('tenants', function (Blueprint $table) {
            if (! Schema::hasColumn('tenants', 'license_code')) {
                $table->string('license_code', 40)->nullable()->unique()->after('slug');
            }
            if (! Schema::hasColumn('tenants', 'api_key')) {
                $table->string('api_key', 80)->nullable()->after('license_code');
            }
            if (! Schema::hasColumn('tenants', 'last_seen_at')) {
                $table->timestamp('last_seen_at')->nullable()->after('suspended_at');
            }
        });

        // Backfill credentials for tenants created before this migration
        foreach (DB::table('tenants')->whereNull('license_code')->get(['id', 'slug', 'name']) as $tenant) {
            DB::table('tenants')->where('id', $tenant->id)->update([
                'license_code' => self::makeLicenseCode($tenant->slug ?: $tenant->name),
                'api_key' => Str::random(40),
            ]);
        }
    }

    public static function makeLicenseCode(string $seed): string
    {
        $clean = preg_replace('/[^A-Za-z0-9]/', '', Str::ascii($seed));
        $clean = substr(str_pad(strtoupper($clean), 4, 'X'), 0, 6);

        return 'PQ-'.$clean.'-'.strtoupper(Str::random(6));
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Intentionally left empty: shared columns, never drop.
    }
};
