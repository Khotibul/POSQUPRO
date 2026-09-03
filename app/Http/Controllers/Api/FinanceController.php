<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class FinanceController extends Controller
{
    public function summary(Request $request)
    {
        $today = Transaction::whereDate('created_at', today())->where('type', 'sell')->where('status', 'completed');
        $month = Transaction::whereMonth('created_at', now()->month)->where('type', 'sell')->where('status', 'completed');

        return response()->json([
            'today_revenue' => (clone $today)->sum('total'),
            'today_transactions' => (clone $today)->count(),
            'month_revenue' => (clone $month)->sum('total'),
            'month_transactions' => (clone $month)->count(),
            'low_stock_count' => Product::whereColumn('stock', '<=', 'min_stock')->count(),
            'by_payment_method' => Transaction::join('payments', 'payments.transaction_id', '=', 'transactions.id')
                ->select('payments.method', DB::raw('SUM(payments.amount) as total'))
                ->groupBy('payments.method')->get(),
        ]);
    }
}
