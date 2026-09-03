<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use Illuminate\Http\Request;

class PaymentController extends Controller
{
    public function index()
    {
        return Payment::with(['transaction'])->latest()->paginate(15);
    }

    public function store(Request $request)
    {
        $data = $request->validate(['transaction_id' => ['required', 'exists:transactions,id'], 'amount' => ['required', 'numeric', 'min:0'], 'method' => ['required', 'in:cash,card,qris,transfer'], 'status' => ['sometimes', 'in:pending,success,failed'], 'notes' => ['nullable', 'string']]);
        $data['paid_at'] = now();

        return Payment::create($data);
    }

    public function show(Payment $payment)
    {
        return $payment->load('transaction');
    }

    public function update(Request $request, Payment $payment)
    {
        $data = $request->validate(['amount' => ['sometimes', 'numeric', 'min:0'], 'method' => ['sometimes', 'in:cash,card,qris,transfer'], 'status' => ['sometimes', 'in:pending,success,failed'], 'notes' => ['nullable', 'string']]);
        $payment->update($data);

        return $payment;
    }

    public function destroy(Payment $payment)
    {
        $payment->delete();

        return response()->json(['message' => 'deleted']);
    }
}
