<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use Illuminate\Http\Request;

class PaymentController extends Controller
{
    public function index(Request $request)
    {
        return Payment::when($request->method, fn ($q, $m) => $q->where('method', strtoupper($m)))
            ->when($request->sale_id, fn ($q, $v) => $q->where('sale_id', $v))
            ->orderByDesc('created_at')->paginate(15);
    }

    public function store(Request $request)
    {
        // Shared Java table `payments`: id, sale_id, method (CASH/CARD/QRIS/TRANSFER), amount, reference_no, created_at
        $data = $request->validate([
            'sale_id' => ['required', 'integer', 'exists:sales,id'],
            'amount' => ['required', 'numeric', 'min:0'],
            'method' => ['required', 'in:CASH,CARD,QRIS,TRANSFER,cash,card,qris,transfer'],
            'reference_no' => ['nullable', 'string', 'max:120'],
        ]);
        $data['method'] = strtoupper($data['method']);

        return Payment::create($data);
    }

    public function show(Payment $payment)
    {
        return $payment;
    }

    public function update(Request $request, Payment $payment)
    {
        $data = $request->validate([
            'amount' => ['sometimes', 'numeric', 'min:0'],
            'method' => ['sometimes', 'in:CASH,CARD,QRIS,TRANSFER,cash,card,qris,transfer'],
            'reference_no' => ['nullable', 'string', 'max:120'],
        ]);
        if (isset($data['method'])) {
            $data['method'] = strtoupper($data['method']);
        }
        $payment->update($data);

        return $payment;
    }

    public function destroy(Payment $payment)
    {
        $payment->delete();

        return response()->json(['message' => 'deleted']);
    }
}
