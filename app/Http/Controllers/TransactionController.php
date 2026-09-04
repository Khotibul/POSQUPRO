<?php

namespace App\Http\Controllers;

use App\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Inertia\Inertia;

class TransactionController extends Controller
{
    public function index(Request $request)
    {
        $transactions = Transaction::with(['customer', 'user', 'items.product'])
            ->when($request->search, fn ($q, $s) => $q->where('invoice_number', 'like', "%{$s}%")
                ->orWhereHas('customer', fn ($qq) => $qq->where('name', 'like', "%{$s}%")))
            ->when($request->type, fn ($q, $v) => $q->where('type', $v))
            ->when($request->status, fn ($q, $v) => $q->where('status', $v))
            ->latest()
            ->paginate(15)
            ->withQueryString();

        // Jika transactions kosong (posqu_pro_desktop awal), tampilkan sales Java (80) agar tidak kosong
        if ($transactions->total() === 0 && Schema::hasTable('sales')) {
            $sales = DB::table('sales')
                ->when($request->search, fn ($q, $s) => $q->where('invoice_no', 'like', "%{$s}%"))
                ->orderByDesc('id')->paginate(15);
            // Map sales ke format transactions agar Vue tetap tampil
            $sales->setCollection($sales->getCollection()->map(fn ($s) => (array) $s + ['invoice_number' => $s->invoice_no, 'type' => 'sell', 'status' => strtolower($s->status), 'total' => $s->total, 'customer' => null, 'user' => null]));

            return Inertia::render('Transactions/Index', [
                'transactions' => $sales,
                'filters' => $request->only(['search', 'type', 'status']),
                'source' => 'sales (Java)',
            ]);
        }

        return Inertia::render('Transactions/Index', [
            'transactions' => $transactions,
            'filters' => $request->only(['search', 'type', 'status']),
        ]);
    }

    public function show(Transaction $transaction)
    {
        return Inertia::render('Transactions/Show', [
            'transaction' => $transaction->load(['customer', 'user', 'items.product', 'payments']),
        ]);
    }
}
