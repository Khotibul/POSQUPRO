<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Models\Transaction;
use Inertia\Inertia;

class DashboardController extends Controller
{
    public function index()
    {
        $stats = [
            'today_revenue' => Transaction::whereDate('created_at', today())->where('type', 'sell')->where('status', 'completed')->sum('total'),
            'today_transactions' => Transaction::whereDate('created_at', today())->where('type', 'sell')->count(),
            'month_revenue' => Transaction::whereMonth('created_at', now()->month)->where('type', 'sell')->sum('total'),
            'low_stock_count' => Product::whereColumn('stock', '<=', 'min_stock')->count(),
        ];

        return Inertia::render('Dashboard/Index', ['stats' => $stats]);
    }
}
