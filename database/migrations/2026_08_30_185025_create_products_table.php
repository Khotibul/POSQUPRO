<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('products')) {
            Schema::create('products', function (Blueprint $table) {
                $table->id();
                $table->string('name');
                $table->string('sku')->unique();
                $table->string('barcode')->nullable()->unique();
                $table->foreignId('category_id')->nullable()->constrained()->nullOnDelete();
                $table->foreignId('unit_quantity_id')->nullable()->constrained('unit_quantities')->nullOnDelete();
                $table->unsignedBigInteger('unit_id')->nullable();
                $table->foreignId('tax_id')->nullable()->constrained('taxes')->nullOnDelete();
                $table->foreignId('supplier_id')->nullable()->constrained('suppliers')->nullOnDelete();
                $table->enum('type', ['raw_material', 'finished_goods', 'service'])->default('finished_goods');
                $table->decimal('cost_price', 15, 2)->default(0);
                $table->decimal('selling_price', 15, 2)->default(0);
                // Java compatibility columns
                $table->decimal('price', 15, 2)->default(0);
                $table->decimal('cost', 15, 2)->default(0);
                $table->decimal('wholesale_price', 15, 2)->nullable();
                $table->integer('min_wholesale')->default(0);
                $table->decimal('product_discount', 5, 2)->default(0);
                $table->decimal('product_tax', 5, 2)->default(0);
                $table->date('expiry_date')->nullable();
                $table->string('category')->nullable();
                $table->string('photo')->nullable();
                $table->decimal('stock', 15, 2)->default(0);
                $table->decimal('min_stock', 15, 2)->default(5);
                $table->string('image')->nullable();
                $table->text('description')->nullable();
                $table->boolean('is_active')->default(true);
                $table->boolean('active')->default(true);
                $table->timestamps();
            });
        } else {
            // Adapt Java products table to Laravel compatibility
            Schema::table('products', function (Blueprint $table) {
                if (! Schema::hasColumn('products', 'category_id') && Schema::hasColumn('products', 'category')) {
                    // Java has 'category' string, add category_id FK
                    $table->foreignId('category_id')->nullable()->after('sku')->constrained('product_categories')->nullOnDelete();
                } elseif (! Schema::hasColumn('products', 'category_id')) {
                    $table->foreignId('category_id')->nullable()->after('sku');
                }
                if (! Schema::hasColumn('products', 'unit_quantity_id') && Schema::hasColumn('products', 'unit_id')) {
                    $table->foreignId('unit_quantity_id')->nullable()->after('category_id');
                } elseif (! Schema::hasColumn('products', 'unit_quantity_id')) {
                    $table->foreignId('unit_quantity_id')->nullable()->after('category_id');
                }
                if (! Schema::hasColumn('products', 'tax_id')) {
                    $table->foreignId('tax_id')->nullable()->after('unit_quantity_id');
                }
                if (! Schema::hasColumn('products', 'supplier_id')) {
                    $table->foreignId('supplier_id')->nullable()->after('tax_id');
                }
                if (! Schema::hasColumn('products', 'type')) {
                    $table->enum('type', ['raw_material', 'finished_goods', 'service'])->default('finished_goods')->after('supplier_id');
                }
                if (! Schema::hasColumn('products', 'cost_price') && Schema::hasColumn('products', 'cost')) {
                    $table->decimal('cost_price', 15, 2)->default(0)->after('type');
                } elseif (! Schema::hasColumn('products', 'cost_price')) {
                    $table->decimal('cost_price', 15, 2)->default(0)->after('type');
                }
                if (! Schema::hasColumn('products', 'selling_price') && Schema::hasColumn('products', 'price')) {
                    $table->decimal('selling_price', 15, 2)->default(0)->after('cost_price');
                } elseif (! Schema::hasColumn('products', 'selling_price')) {
                    $table->decimal('selling_price', 15, 2)->default(0)->after('cost_price');
                }
                if (! Schema::hasColumn('products', 'image') && Schema::hasColumn('products', 'photo')) {
                    $table->string('image')->nullable()->after('min_stock');
                } elseif (! Schema::hasColumn('products', 'image')) {
                    $table->string('image')->nullable()->after('min_stock');
                }
                if (! Schema::hasColumn('products', 'description')) {
                    $table->text('description')->nullable()->after('image');
                }
                if (! Schema::hasColumn('products', 'is_active') && Schema::hasColumn('products', 'active')) {
                    $table->boolean('is_active')->default(true)->after('description');
                } elseif (! Schema::hasColumn('products', 'is_active')) {
                    $table->boolean('is_active')->default(true)->after('description');
                }
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};
