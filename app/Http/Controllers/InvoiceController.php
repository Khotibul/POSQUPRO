<?php

namespace App\Http\Controllers;

use App\Models\Invoice;
use App\Models\Plan;
use App\Models\Tenant;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;

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
            ->paginate(15)
            ->withQueryString();

        $stats = [
            'total' => Invoice::count(),
            'paid' => Invoice::where('status', 'paid')->count(),
            'pending' => Invoice::where('status', 'pending')->count(),
            'overdue' => Invoice::where('status', 'pending')->where('due_at', '<', now())->count(),
            'total_revenue' => Invoice::where('status', 'paid')->sum('total'),
            'outstanding' => Invoice::where('status', 'pending')->sum('total'),
        ];

        return Inertia::render('Billing/Invoices', compact('invoices', 'stats'));
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

        return back()->with('success', "Invoice {$invoice->invoice_number} dibuat");
    }

    public function markPaid(Invoice $invoice)
    {
        $invoice->update([
            'status' => 'paid',
            'paid_at' => now(),
            'amount_paid' => $invoice->total,
            'payment_method' => request('payment_method', 'bank_transfer'),
        ]);

        return back()->with('success', "Invoice {$invoice->invoice_number} ditandai lunas");
    }

    public function destroy(Invoice $invoice)
    {
        $invoice->delete();
        return back()->with('success', 'Invoice dihapus');
    }
}
