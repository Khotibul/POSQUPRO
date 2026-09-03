<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('settings')) {
            Schema::create('settings', function (Blueprint $table) {
                $table->id();
                $table->string('key')->unique();
                $table->string('group')->default('general');
                $table->text('value')->nullable();
                $table->string('type')->default('string');
                $table->string('label')->nullable();
                $table->text('description')->nullable();
                $table->boolean('is_public')->default(false);
                $table->timestamps();
            });
        } else {
            // Java settings has setting_key, setting_value, setting_group - add Laravel columns
            Schema::table('settings', function (Blueprint $table) {
                if (! Schema::hasColumn('settings', 'key') && Schema::hasColumn('settings', 'setting_key')) {
                    $table->string('key')->nullable()->after('id');
                } elseif (! Schema::hasColumn('settings', 'key')) {
                    $table->string('key')->nullable()->after('id');
                }
                if (! Schema::hasColumn('settings', 'group') && Schema::hasColumn('settings', 'setting_group')) {
                    $table->string('group')->default('general')->after('key');
                } elseif (! Schema::hasColumn('settings', 'group')) {
                    $table->string('group')->default('general')->after('key');
                }
                if (! Schema::hasColumn('settings', 'value') && Schema::hasColumn('settings', 'setting_value')) {
                    $table->text('value')->nullable()->after('group');
                } elseif (! Schema::hasColumn('settings', 'value')) {
                    $table->text('value')->nullable()->after('group');
                }
                if (! Schema::hasColumn('settings', 'type')) {
                    $table->string('type')->default('string')->after('value');
                }
                if (! Schema::hasColumn('settings', 'label')) {
                    $table->string('label')->nullable()->after('type');
                }
                if (! Schema::hasColumn('settings', 'description')) {
                    $table->text('description')->nullable()->after('label');
                }
                if (! Schema::hasColumn('settings', 'is_public')) {
                    $table->boolean('is_public')->default(false)->after('description');
                }
                if (! Schema::hasColumn('settings', 'created_at')) {
                    $table->timestamp('created_at')->nullable()->after('is_public');
                }
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('settings');
    }
};
