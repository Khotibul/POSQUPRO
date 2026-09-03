<?php

namespace App\Http\Controllers;

use App\Models\ParkedTransaction;
use Inertia\Inertia;

class ParkedTransactionController extends Controller
{
    public function index()
    {
        $parkedTransactions = ParkedTransaction::with(['customer', 'user'])->latest()->paginate(15);

        return Inertia::render('ParkedTransactions/Index', [
            'parkedTransactions' => $parkedTransactions,
        ]);
    }
}
