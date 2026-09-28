<?php

namespace App\Services;

use App\Support\SettingsStore;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class SettingService
{
    public function get(string $key, $default = null)
    {
        return Cache::remember("setting.{$key}", 3600, fn () => SettingsStore::get($key, $default));
    }

    public function set(string $key, $value, string $type = 'string', string $group = 'general', ?string $label = null, ?string $description = null): bool
    {
        // Extra metadata (type/label/description) only exists on Laravel-style schema
        if (SettingsStore::mode() === 'laravel') {
            $row = ['value' => is_array($value) || is_object($value) ? json_encode($value) : (string) ($value ?? '')];
            if (Schema::hasColumn('settings', 'type')) {
                $row['type'] = $type;
            }
            if ($label !== null && Schema::hasColumn('settings', 'label')) {
                $row['label'] = $label;
            }
            if ($description !== null && Schema::hasColumn('settings', 'description')) {
                $row['description'] = $description;
            }
            if (Schema::hasColumn('settings', 'updated_at')) {
                $row['updated_at'] = now();
            }
            $exists = DB::table('settings')->where('key', $key)->exists();
            if ($exists) {
                DB::table('settings')->where('key', $key)->update($row);
            } else {
                $row['key'] = $key;
                $row['group'] = $group;
                if (Schema::hasColumn('settings', 'created_at')) {
                    $row['created_at'] = now();
                }
                DB::table('settings')->insert($row);
            }
        } else {
            SettingsStore::set($key, $value, $group);
        }
        Cache::forget("setting.{$key}");

        return true;
    }

    public function getGroup(string $group): array
    {
        return SettingsStore::getGroup($group);
    }

    public function getPublic(): array
    {
        return SettingsStore::getPublic();
    }
}
