<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use App\Services\PlanService;
use App\Services\ProductService;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function __construct(protected ProductService $service) {}

    public function index(Request $request)
    {
        $products = $this->service->paginate($request->only(['search', 'category_id', 'type']), 15);

        return ProductResource::collection($products);
    }

    public function store(Request $request)
    {
        // Check plan limit
        $planService = app(PlanService::class);
        if (! $planService->canAddProduct()) {
            return response()->json([
                'message' => 'Batas maksimal produk tercapai. Upgrade paket Anda untuk menambah produk.',
                'limits' => $planService->getLimitsSummary(),
            ], 403);
        }

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'sku' => ['nullable', 'string', 'unique:products,sku'],
            'barcode' => ['nullable', 'string', 'unique:products,barcode'],
            'category_id' => ['nullable', 'exists:categories,id'],
            'unit_quantity_id' => ['nullable', 'exists:unit_quantities,id'],
            'tax_id' => ['nullable', 'exists:taxes,id'],
            'supplier_id' => ['nullable', 'exists:suppliers,id'],
            'type' => ['required', 'in:raw_material,finished_goods,service'],
            'cost_price' => ['required', 'numeric', 'min:0'],
            'selling_price' => ['required', 'numeric', 'min:0'],
            'stock' => ['required', 'integer', 'min:0'],
            'min_stock' => ['nullable', 'integer', 'min:0'],
            'description' => ['nullable', 'string'],
            'is_active' => ['boolean'],
        ]);

        $product = $this->service->create($data);

        return new ProductResource($product->load(['category', 'unitQuantity', 'tax', 'supplier']));
    }

    public function show(Product $product)
    {
        return new ProductResource($product->load(['category', 'unitQuantity', 'tax', 'supplier']));
    }

    public function update(Request $request, Product $product)
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'sku' => ['sometimes', 'string', 'unique:products,sku,'.$product->id],
            'barcode' => ['nullable', 'string', 'unique:products,barcode,'.$product->id],
            'category_id' => ['nullable', 'exists:categories,id'],
            'unit_quantity_id' => ['nullable', 'exists:unit_quantities,id'],
            'tax_id' => ['nullable', 'exists:taxes,id'],
            'supplier_id' => ['nullable', 'exists:suppliers,id'],
            'type' => ['sometimes', 'in:raw_material,finished_goods,service'],
            'cost_price' => ['sometimes', 'numeric', 'min:0'],
            'selling_price' => ['sometimes', 'numeric', 'min:0'],
            'stock' => ['sometimes', 'integer', 'min:0'],
            'min_stock' => ['nullable', 'integer', 'min:0'],
            'description' => ['nullable', 'string'],
            'is_active' => ['boolean'],
        ]);

        $product = $this->service->update($product, $data);

        return new ProductResource($product);
    }

    public function destroy(Product $product)
    {
        $this->service->delete($product);

        return response()->json(['message' => 'Product deleted']);
    }
}
