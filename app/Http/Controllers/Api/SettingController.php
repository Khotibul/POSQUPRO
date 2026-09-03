<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\SettingResource;
use App\Models\Setting;
use App\Services\SettingService;
use Illuminate\Http\Request;

class SettingController extends Controller
{
    public function __construct(protected SettingService $service) {}

    public function index(Request $request)
    {
        return SettingResource::collection(Setting::when($request->group, fn ($q, $v) => $q->where('group', $v))->latest()->paginate(50));
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
        $data = $request->validate([
            'key' => ['required', 'string', 'unique:settings,key'],
            'group' => ['nullable', 'string'],
            'value' => ['nullable'],
            'type' => ['sometimes', 'in:string,json,boolean,integer,decimal'],
            'label' => ['nullable', 'string'],
            'description' => ['nullable', 'string'],
            'is_public' => ['boolean'],
        ]);

        return new SettingResource($this->service->set(
            $data['key'], $data['value'] ?? '', $data['type'] ?? 'string', $data['group'] ?? 'general', $data['label'] ?? null, $data['description'] ?? null
        ));
    }

    public function update(Request $request, Setting $setting)
    {
        $data = $request->validate([
            'value' => ['nullable'],
            'type' => ['sometimes', 'in:string,json,boolean,integer,decimal'],
            'label' => ['nullable', 'string'],
            'description' => ['nullable', 'string'],
            'is_public' => ['boolean'],
        ]);

        return new SettingResource($this->service->set(
            $setting->key, $data['value'] ?? $setting->value, $data['type'] ?? $setting->type, $setting->group, $data['label'] ?? $setting->label, $data['description'] ?? $setting->description
        ));
    }
}
