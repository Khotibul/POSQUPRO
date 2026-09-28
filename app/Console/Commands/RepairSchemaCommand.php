<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class RepairSchemaCommand extends Command
{
    protected $signature = 'app:repair-schema {--check : Only report drift, do not modify anything}';

    protected $description = 'Repair shared Java/Laravel schema drift (idempotent, safe to run on production)';

    /** @var array<string, array<string, callable>> */
    protected array $columns = [];

    public function handle(): int
    {
        $checkOnly = (bool) $this->option('check');
        $problems = 0;
        $repaired = 0;

        $this->columns = [
            'users' => [
                'tenant_id' => fn ($t) => $t->unsignedBigInteger('tenant_id')->nullable()->after('id'),
                'google_id' => fn ($t) => $t->string('google_id')->nullable()->after('id'),
                'phone' => fn ($t) => $t->string('phone')->nullable()->after('email'),
                'avatar' => fn ($t) => $t->string('avatar')->nullable()->after('email'),
                'password' => fn ($t) => $t->string('password')->nullable()->after('avatar'),
                'is_active' => fn ($t) => $t->boolean('is_active')->default(true)->after('phone'),
                'last_login_at' => fn ($t) => $t->timestamp('last_login_at')->nullable()->after('is_active'),
                'email_verified_at' => fn ($t) => $t->timestamp('email_verified_at')->nullable()->after('email'),
                'remember_token' => fn ($t) => $t->rememberToken()->after('password'),
            ],
            'products' => [
                'selling_price' => fn ($t) => $t->decimal('selling_price', 15, 2)->nullable()->after('price'),
                'cost_price' => fn ($t) => $t->decimal('cost_price', 15, 2)->nullable()->after('cost'),
                'is_active' => fn ($t) => $t->boolean('is_active')->default(true)->after('active'),
                'image' => fn ($t) => $t->string('image')->nullable()->after('photo'),
                'description' => fn ($t) => $t->text('description')->nullable()->after('name'),
                'tax_id' => fn ($t) => $t->unsignedBigInteger('tax_id')->nullable()->after('category_id'),
                'supplier_id' => fn ($t) => $t->unsignedBigInteger('supplier_id')->nullable()->after('tax_id'),
                'type' => fn ($t) => $t->string('type', 50)->nullable()->after('barcode'),
                'unit_quantity_id' => fn ($t) => $t->unsignedBigInteger('unit_quantity_id')->nullable()->after('unit_id'),
                'tenant_id' => fn ($t) => $t->unsignedBigInteger('tenant_id')->nullable()->after('id'),
            ],
            'customers' => [
                'is_active' => fn ($t) => $t->boolean('is_active')->default(true)->after('active'),
                'credit_limit' => fn ($t) => $t->decimal('credit_limit', 12, 2)->default(0)->after('address'),
                'credit_balance' => fn ($t) => $t->decimal('credit_balance', 12, 2)->default(0)->after('credit_limit'),
            ],
            'suppliers' => [
                'contact_person' => fn ($t) => $t->string('contact_person')->nullable()->after('address'),
                'is_active' => fn ($t) => $t->boolean('is_active')->default(true)->after('contact_person'),
            ],
            'units' => [
                'description' => fn ($t) => $t->text('description')->nullable()->after('symbol'),
                'updated_at' => fn ($t) => $t->timestamp('updated_at')->nullable()->after('created_at'),
            ],
            'branches' => [
                'is_active' => fn ($t) => $t->boolean('is_active')->default(true)->after('active'),
                'tenant_id' => fn ($t) => $t->unsignedBigInteger('tenant_id')->nullable()->after('id'),
            ],
            'warehouses' => [
                'is_active' => fn ($t) => $t->boolean('is_active')->default(true)->after('active'),
                'tenant_id' => fn ($t) => $t->unsignedBigInteger('tenant_id')->nullable()->after('id'),
            ],
            'taxes' => [
                'is_active' => fn ($t) => $t->boolean('is_active')->default(true)->after('rate'),
                'updated_at' => fn ($t) => $t->timestamp('updated_at')->nullable()->after('created_at'),
            ],
        ];

        foreach ($this->columns as $table => $cols) {
            if (! Schema::hasTable($table)) {
                $this->warn("table missing: {$table}");
                $problems++;

                continue;
            }
            foreach ($cols as $column => $define) {
                if (Schema::hasColumn($table, $column)) {
                    continue;
                }
                $problems++;
                if ($checkOnly) {
                    $this->warn("missing column: {$table}.{$column}");

                    continue;
                }
                Schema::table($table, function ($blueprint) use ($define) {
                    $define($blueprint);
                });
                $this->info("added column: {$table}.{$column}");
                $repaired++;
            }
        }

        foreach (['expenses', 'payment_methods', 'units', 'branches', 'warehouses'] as $table) {
            if (! Schema::hasTable($table)) {
                $this->warn("table missing: {$table} (run php artisan migrate)");
                $problems++;
            }
        }

        if ($checkOnly) {
            $this->info("Check complete. Problems found: {$problems}. Run without --check to repair.");

            return self::SUCCESS;
        }

        // Backfills: dual Java/Laravel columns must agree
        foreach ([
            ['users', 'is_active', 'active'],
            ['users', 'password', 'password_hash'],
            ['products', 'selling_price', 'price'],
            ['products', 'cost_price', 'cost'],
            ['products', 'is_active', 'active'],
            ['customers', 'is_active', 'active'],
            ['suppliers', 'is_active', 'active'],
            ['branches', 'is_active', 'active'],
            ['warehouses', 'is_active', 'active'],
        ] as [$table, $target, $source]) {
            if (Schema::hasColumn($table, $target)) {
                DB::table($table)->whereNull($target)->update([$target => DB::raw($source)]);
            }
        }

        $this->info("Repair complete. Columns added: {$repaired}. Remaining problems: {$problems}.");

        return self::SUCCESS;
    }
}
