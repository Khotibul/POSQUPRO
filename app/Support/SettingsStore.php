<?php

namespace App\Support;

use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Schema-aware access to the shared `settings` table.
 *
 * Production uses Laravel-style columns (key, value, group, type, label,
 * description, is_public), while Java/desktop installs use
 * (setting_key, setting_value, setting_group). All reads return normalized
 * ['id', 'key', 'value', 'group'] rows so callers never touch a missing column.
 */
class SettingsStore
{
    protected static ?string $mode = null;

    /**
     * Detect schema: 'laravel', 'java', or null when table is missing.
     */
    public static function mode(): ?string
    {
        if (self::$mode !== null) {
            return self::$mode;
        }

        if (! Schema::hasTable('settings')) {
            return self::$mode = null;
        }

        if (Schema::hasColumn('settings', 'key')) {
            return self::$mode = 'laravel';
        }

        if (Schema::hasColumn('settings', 'setting_key')) {
            return self::$mode = 'java';
        }

        return self::$mode = null;
    }

    public static function resetMode(): void
    {
        self::$mode = null;
    }

    /**
     * All settings normalized to ['id', 'key', 'value', 'group'].
     *
     * @return array<int, array{id: mixed, key: string, value: ?string, group: ?string}>
     */
    public static function all(): array
    {
        return match (self::mode()) {
            'laravel' => DB::table('settings')->orderBy('id')->get(['id', 'key', 'value', 'group'])
                ->map(fn ($s) => ['id' => $s->id, 'key' => $s->key, 'value' => $s->value, 'group' => $s->group])->all(),
            'java' => DB::table('settings')->whereNotNull('setting_key')->orderBy('id')->get(['id', 'setting_key', 'setting_value', 'setting_group'])
                ->map(fn ($s) => ['id' => $s->id, 'key' => $s->setting_key, 'value' => $s->setting_value, 'group' => $s->setting_group])->all(),
            default => [],
        };
    }

    /**
     * Key => value map (for POS/printer/store settings).
     */
    public static function map(): array
    {
        $map = [];
        foreach (self::all() as $row) {
            $map[$row['key']] = $row['value'];
        }

        return $map;
    }

    public static function get(string $key, $default = null)
    {
        $map = self::map();

        return $map[$key] ?? $default;
    }

    public static function getGroup(string $group): array
    {
        return collect(self::all())->where('group', $group)->mapWithKeys(fn ($r) => [$r['key'] => $r['value']])->all();
    }

    public static function getPublic(): array
    {
        if (self::mode() !== 'laravel' || ! Schema::hasColumn('settings', 'is_public')) {
            return [];
        }

        return DB::table('settings')->where('is_public', true)->get(['key', 'value'])
            ->mapWithKeys(fn ($s) => [$s->key => $s->value])->all();
    }

    /**
     * Update-or-insert a single key without ever touching a missing column.
     */
    public static function set(string $key, $value, string $group = 'general'): bool
    {
        $value = is_array($value) || is_object($value) ? json_encode($value) : (string) ($value ?? '');

        if (self::mode() === 'laravel') {
            $exists = DB::table('settings')->where('key', $key)->exists();
            $row = ['value' => $value, 'group' => $group];
            if (Schema::hasColumn('settings', 'updated_at')) {
                $row['updated_at'] = now();
            }
            if ($exists) {
                DB::table('settings')->where('key', $key)->update($row);
            } else {
                $row['key'] = $key;
                if (Schema::hasColumn('settings', 'created_at')) {
                    $row['created_at'] = now();
                }
                DB::table('settings')->insert($row);
            }

            return true;
        }

        if (self::mode() === 'java') {
            $exists = DB::table('settings')->where('setting_key', $key)->exists();
            $row = ['setting_value' => $value, 'setting_group' => $group];
            if (Schema::hasColumn('settings', 'updated_at')) {
                $row['updated_at'] = now();
            }
            if ($exists) {
                DB::table('settings')->where('setting_key', $key)->update($row);
            } else {
                $row['setting_key'] = $key;
                DB::table('settings')->insert($row);
            }

            return true;
        }

        return false;
    }

    public static function paginate(int $perPage = 50): LengthAwarePaginator
    {
        $all = collect(self::all());

        $page = max(1, (int) request()->integer('page', 1));

        return new LengthAwarePaginator(
            $all->forPage($page, $perPage)->values(),
            $all->count(),
            $perPage,
            $page,
            ['path' => request()->url(), 'query' => request()->query()]
        );
    }
}
