<?php

namespace App\Http\Controllers;

use App\Models\Customer;
use App\Models\Product;
use App\Services\TransactionService;
use Illuminate\Http\Request;
use Inertia\Inertia;

class PosController extends Controller
{
    public function index(Request $request)
    {
        // Optimasi: paginasi + search server-side, tidak load 33k sekaligus (hemat memori)
        $products = Product::with(['category'])
            ->where('is_active', true)
            ->when($request->search, fn ($q, $s) => $q->where(fn ($qq) => $qq->where('name', 'like', "%{$s}%")->orWhere('sku', 'like', "%{$s}%")->orWhere('barcode', 'like', "%{$s}%")))
            ->when($request->category, fn ($q, $c) => $q->whereHas('category', fn ($qq) => $qq->where('name', $c))->orWhere('category', $c))
            ->orderBy('name')
            ->paginate(24)
            ->withQueryString();

        return Inertia::render('POS/Index', [
            'products' => $products,
            'customers' => Customer::select('id', 'name', 'phone')->where('is_active', true)->orWhere('active', 1)->limit(100)->get(),
            'categories' => \App\Models\Category::select('id', 'name')->where('is_active', true)->get(),
            'filters' => $request->only(['search', 'category']),
        ]);
    }

    public function checkoutPage(Request $request)
    {
        // Halaman checkout terpisah (menu page, bukan popup) - hemat memori
        return Inertia::render('POS/Checkout', [
            'customers' => Customer::select('id', 'name')->where('is_active', true)->orWhere('active', 1)->limit(100)->get(),
        ]);
    }

    public function parkPage()
    {
        return Inertia::render('POS/Park', [
            'parked' => \App\Models\ParkedTransaction::with(['customer'])->latest()->limit(20)->get(),
        ]);
    }

    public function checkout(Request $request, TransactionService $service)
    {
        $data = $request->validate([
            'type' => ['sometimes', 'in:buy,sell'],
            'customer_id' => ['nullable', 'exists:customers,id'],
            'discount' => ['nullable', 'numeric'],
            'tax_amount' => ['nullable', 'numeric'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.unit_price' => ['required', 'numeric'],
            'payment' => ['nullable', 'array'],
            'payment.method' => ['nullable', 'in:cash,card,qris,transfer'],
        ]);

        $data['type'] = $data['type'] ?? 'sell';
        $data['user_id'] = auth()->id();

        $service->create($data);

        return redirect()->back()->with('success', 'Transaksi berhasil!');
    }
}
