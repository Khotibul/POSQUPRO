<?php

namespace App\Services;

use App\Models\Setting;
use Illuminate\Support\Facades\Cache;

class SettingService
{
    public function get(string $key, $default = null)
    {
        return Cache::remember("setting.{$key}", 3600, fn () => Setting::get($key, $default));
    }

    public function set(string $key, $value, string $type = 'string', string $group = 'general', ?string $label = null, ?string $description = null): Setting
    {
        $setting = Setting::set($key, $value, $type, $group);
        if ($label) {
            $setting->update(['label' => $label]);
        }
        if ($description) {
            $setting->update(['description' => $description]);
        }
        Cache::forget("setting.{$key}");

        return $setting;
    }

    public function getGroup(string $group): array
    {
        return Setting::where('group', $group)->get()->mapWithKeys(fn ($s) => [$s->key => $s->typed_value])->toArray();
    }

    public function getPublic(): array
    {
        return Setting::where('is_public', true)->get()->mapWithKeys(fn ($s) => [$s->key => $s->typed_value])->toArray();
    }
}
