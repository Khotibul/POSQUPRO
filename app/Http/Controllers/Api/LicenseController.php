<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Tenant;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * SaaS endpoints consumed by posqupro-desktop (Java SaaSClient):
 * - POST /api/license/validate {licenseCode} + X-API-Key
 * - POST /api/monitoring/update {...} + X-API-Key
 * - POST /api/payment/update {...} + X-API-Key
 */
class LicenseController extends Controller
{
    public function validate(Request $request)
    {
        $data = $request->validate([
            'licenseCode' => ['required', 'string'],
        ]);

        $tenant = Tenant::with('plan')->where('license_code', $data['licenseCode'])->first();

        if (! $tenant) {
            return response()->json(['valid' => false, 'error' => 'Kode lisensi tidak terdaftar.'], 404);
        }

        if (! $this->apiKeyMatches($request, $tenant)) {
            return response()->json(['valid' => false, 'error' => 'API key tidak valid.'], 401);
        }

        if ($tenant->status === 'suspended' || $tenant->status === 'inactive') {
            return response()->json([
                'valid' => false,
                'licenseCode' => $tenant->license_code,
                'status' => $tenant->status,
                'error' => 'Tenant ditangguhkan. Hubungi administrator.',
            ], 403);
        }

        return response()->json([
            'valid' => true,
            'licenseCode' => $tenant->license_code,
            'paket' => $tenant->plan?->name ?? '-',
            'status' => $tenant->status,
            'expiredAt' => $tenant->trial_ends_at?->toIso8601String(),
            'namaPengguna' => $tenant->name,
        ]);
    }

    public function monitoring(Request $request)
    {
        $tenant = $this->tenantFromApiKey($request);
        if (! $tenant) {
            return response()->json(['message' => 'API key tidak valid.'], 401);
        }

        $tenant->update(['last_seen_at' => now()]);
        Log::info('Desktop monitoring heartbeat', ['tenant_id' => $tenant->id]);

        return response()->json(['message' => 'ok']);
    }

    public function payment(Request $request)
    {
        $tenant = $this->tenantFromApiKey($request);
        if (! $tenant) {
            return response()->json(['message' => 'API key tidak valid.'], 401);
        }

        Log::info('Desktop payment report', ['tenant_id' => $tenant->id, 'payload' => $request->all()]);

        return response()->json(['message' => 'ok']);
    }

    protected function tenantFromApiKey(Request $request): ?Tenant
    {
        $apiKey = $request->header('X-API-Key', '');
        if ($apiKey === '') {
            return null;
        }

        return Tenant::where('api_key', $apiKey)->first();
    }

    protected function apiKeyMatches(Request $request, Tenant $tenant): bool
    {
        $apiKey = $request->header('X-API-Key', '');

        // Empty api_key on tenant = accept any (legacy tenants before backfill)
        if (empty($tenant->api_key)) {
            return true;
        }

        return hash_equals($tenant->api_key, $apiKey);
    }
}
