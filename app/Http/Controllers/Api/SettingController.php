<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\SettingService;
use App\Support\SettingsStore;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;

class SettingController extends Controller
{
    public function __construct(protected SettingService $service) {}

    public function index(Request $request)
    {
        $all = collect(SettingsStore::all());
        if ($request->group) {
            $all = $all->where('group', $request->group)->values();
        }

        $perPage = 50;
        $page = max(1, (int) $request->integer('page', 1));

        return new LengthAwarePaginator(
            $all->forPage($page, $perPage)->values(),
            $all->count(),
            $perPage,
            $page,
            ['path' => $request->url(), 'query' => $request->query()]
        );
    }

    public function public()
    {
        return response()->json($this->service->getPublic());
    }

    public function group(string $group)
    {
        return response()->json($this->service->getGroup($group));
    }

    public function store(Request $request)
    {
        // Accept both Laravel-style (key/value) and legacy mobile (setting_key/setting_value) payloads
        $data = $request->validate([
            'key' => ['nullable', 'string'],
            'setting_key' => ['nullable', 'string'],
            'group' => ['nullable', 'string'],
            'setting_group' => ['nullable', 'string'],
            'value' => ['nullable'],
            'setting_value' => ['nullable'],
            'type' => ['sometimes', 'in:string,json,boolean,integer,decimal'],
            'label' => ['nullable', 'string'],
            'description' => ['nullable', 'string'],
            'is_public' => ['boolean'],
        ]);

        $key = $data['key'] ?? $data['setting_key'] ?? null;
        if (! $key) {
            return response()->json(['message' => 'key wajib diisi.'], 422);
        }

        $this->service->set(
            $key,
            $data['value'] ?? $data['setting_value'] ?? '',
            $data['type'] ?? 'string',
            $data['group'] ?? $data['setting_group'] ?? 'general',
            $data['label'] ?? null,
            $data['description'] ?? null
        );

        return response()->json(['key' => $key, 'value' => $data['value'] ?? $data['setting_value'] ?? ''], 201);
    }

    public function update(Request $request, string $id)
    {
        $data = $request->validate([
            'value' => ['nullable'],
            'setting_value' => ['nullable'],
            'type' => ['sometimes', 'in:string,json,boolean,integer,decimal'],
            'label' => ['nullable', 'string'],
            'description' => ['nullable', 'string'],
            'is_public' => ['boolean'],
        ]);

        $row = collect(SettingsStore::all())->firstWhere('id', (int) $id);
        if (! $row) {
            return response()->json(['message' => 'Setting tidak ditemukan.'], 404);
        }

        $this->service->set($row['key'], $data['value'] ?? $data['setting_value'] ?? $row['value'], $data['type'] ?? 'string', $row['group'] ?? 'general', $data['label'] ?? null, $data['description'] ?? null);

        return response()->json(['key' => $row['key'], 'value' => $data['value'] ?? $data['setting_value'] ?? $row['value']]);
    }

    public function show(string $id)
    {
        $row = collect(SettingsStore::all())->firstWhere('id', (int) $id);
        if (! $row) {
            return response()->json(['message' => 'Setting tidak ditemukan.'], 404);
        }

        return response()->json($row);
    }

    public function destroy(string $id)
    {
        $row = collect(SettingsStore::all())->firstWhere('id', (int) $id);
        if (! $row) {
            return response()->json(['message' => 'Setting tidak ditemukan.'], 404);
        }

        if (SettingsStore::mode() === 'laravel') {
            DB::table('settings')->where('key', $row['key'])->delete();
        } else {
            DB::table('settings')->where('setting_key', $row['key'])->delete();
        }

        return response()->json(['message' => 'deleted']);
    }
}
