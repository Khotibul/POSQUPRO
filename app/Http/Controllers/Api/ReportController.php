<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\InventoryHistory;
use App\Models\Product;
use App\Models\Transaction;
use App\Models\TransactionItem;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ReportController extends Controller
{
    public function sales(Request $request)
    {
        $query = Transaction::where('type', 'sell')
            ->when($request->from, fn ($q) => $q->whereDate('created_at', '>=', $request->from))
            ->when($request->to, fn ($q) => $q->whereDate('created_at', '<=', $request->to));

        return response()->json([
            'total_revenue' => (clone $query)->sum('total'),
            'total_transactions' => (clone $query)->count(),
            'daily' => (clone $query)->select(DB::raw('DATE(created_at) as date'), DB::raw('SUM(total) as total'), DB::raw('COUNT(*) as count'))
                ->groupBy(DB::raw('DATE(created_at)'))->orderBy('date')->get(),
            'top_products' => TransactionItem::select('product_id', DB::raw('SUM(quantity) as qty'), DB::raw('SUM(subtotal) as revenue'))
                ->groupBy('product_id')->orderByDesc('qty')->with('product')->limit(5)->get(),
        ]);
    }

    public function inventory(Request $request)
    {
        return response()->json([
            'total_products' => Product::count(),
            'low_stock' => Product::whereColumn('stock', '<=', 'min_stock')->with(['category'])->get(),
            'stock_value' => Product::selectRaw('SUM(stock * cost_price) as cost_value, SUM(stock * selling_price) as sell_value')->first(),
            'movements' => InventoryHistory::with(['product', 'user'])->latest()->limit(20)->get(),
        ]);
    }
}
