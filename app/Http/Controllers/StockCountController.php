<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Models\StockCount;
use Inertia\Inertia;

class StockCountController extends Controller
{
    public function index()
    {
        $stockCounts = StockCount::with(['user', 'approver', 'items.product'])->latest()->paginate(15);
        $products = Product::where('is_active', true)->get();

        return Inertia::render('StockCounts/Index', [
            'stockCounts' => $stockCounts,
            'products' => $products,
        ]);
    }
}
