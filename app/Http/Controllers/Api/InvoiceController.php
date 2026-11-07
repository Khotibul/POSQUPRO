<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Invoice;
use App\Models\Plan;
use Illuminate\Http\Request;

class InvoiceController extends Controller
{
    public function index(Request $request)
    {
        $invoices = Invoice::with(['tenant', 'plan'])
            ->when($request->search, function ($q, $s) {
                $q->where('invoice_number', 'like', "%{$s}%")
                    ->orWhereHas('tenant', fn ($t) => $t->where('name', 'like', "%{$s}%"));
            })
            ->when($request->status, fn ($q, $s) => $q->where('status', $s))
            ->latest()
            ->paginate(15);

        return $invoices;
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'tenant_id' => 'required|exists:tenants,id',
            'plan_id' => 'required|exists:plans,id',
            'amount' => 'nullable|numeric|min:0',
            'notes' => 'nullable|string',
        ]);

        $plan = Plan::findOrFail($validated['plan_id']);
        $amount = $validated['amount'] ?? $plan->price;
        $taxAmount = round($amount * 0.11, 2);

        $invoice = Invoice::create([
            'tenant_id' => $validated['tenant_id'],
            'plan_id' => $validated['plan_id'],
            'subtotal' => $amount,
            'tax_amount' => $taxAmount,
            'total' => $amount + $taxAmount,
            'status' => 'pending',
            'issued_at' => now(),
            'due_at' => now()->addDays(7),
            'notes' => $validated['notes'] ?? null,
            'items' => [
                ['description' => "Paket {$plan->name}", 'amount' => $amount, 'quantity' => 1],
            ],
        ]);

        return response()->json($invoice->load(['tenant', 'plan']), 201);
    }

    public function show(Invoice $invoice)
    {
        return $invoice->load(['tenant', 'plan']);
    }

    public function markPaid(Invoice $invoice)
    {
        $invoice->update([
            'status' => 'paid',
            'paid_at' => now(),
            'amount_paid' => $invoice->total,
            'payment_method' => request('payment_method', 'bank_transfer'),
        ]);

        return $invoice->load(['tenant', 'plan']);
    }

    public function destroy(Invoice $invoice)
    {
        $invoice->delete();

        return response()->json(['message' => 'deleted']);
    }
}
