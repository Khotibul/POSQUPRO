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

        $recentTransactions = Transaction::with(['customer', 'user'])
            ->whereDate('created_at', today())
            ->latest()
            ->limit(5)
            ->get();

        $lowStockProducts = Product::whereColumn('stock', '<=', 'min_stock')
            ->orderBy('stock')
            ->limit(10)
            ->get();

        return Inertia::render('Dashboard/Index', [
            'stats' => $stats,
            'recentTransactions' => $recentTransactions,
            'lowStockProducts' => $lowStockProducts,
        ]);
    }
}
