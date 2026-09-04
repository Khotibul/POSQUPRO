<?php

namespace App\Http\Controllers;

use App\Models\Category;
use App\Models\Customer;
use App\Models\ParkedTransaction;
use App\Models\Product;
use App\Services\ParkedTransactionService;
use App\Services\SaleService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;

class PosController extends Controller
{
    public function index(Request $request)
    {
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
            'categories' => Category::select('id', 'name')->where('is_active', true)->get(),
            'filters' => $request->only(['search', 'category']),
        ]);
    }

    public function checkoutPage(Request $request)
    {
        return Inertia::render('POS/Checkout', [
            'customers' => Customer::select('id', 'name')->where('is_active', true)->orWhere('active', 1)->limit(100)->get(),
            'settings' => $this->getPosSettings(),
        ]);
    }

    public function parkPage()
    {
        return Inertia::render('POS/Park', [
            'parked' => ParkedTransaction::with(['customer'])->latest()->limit(20)->get(),
        ]);
    }

    public function park(Request $request, ParkedTransactionService $service)
    {
        $data = $request->validate([
            'customer_id' => ['nullable', 'exists:customers,id'],
            'items' => ['required', 'array', 'min:1'],
            'notes' => ['nullable', 'string'],
        ]);

        foreach ($data['items'] as &$item) {
            $item['quantity'] = $item['qty'] ?? $item['quantity'] ?? 1;
            $item['unit_price'] = $item['price'] ?? $item['unit_price'] ?? 0;
        }

        $data['user_id'] = auth()->id();
        $service->create($data);

        return redirect()->back()->with('success', 'Transaksi diparkir!');
    }

    public function destroyPark(Request $request, string $id, ParkedTransactionService $service)
    {
        $parked = ParkedTransaction::findOrFail($id);
        $service->delete($parked);

        return redirect()->back()->with('success', 'Parkir dihapus!');
    }

    public function checkout(Request $request, SaleService $service)
    {
        $data = $request->validate([
            'type' => ['sometimes', 'in:buy,sell'],
            'customer_id' => ['nullable', 'exists:customers,id'],
            'discount' => ['nullable', 'numeric'],
            'tax_amount' => ['nullable', 'numeric'],
            'paid_amount' => ['required', 'numeric', 'min:0'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.unit_price' => ['required', 'numeric'],
            'payment' => ['nullable', 'array'],
            'payment.method' => ['nullable', 'in:cash,card,qris,transfer'],
            'payment.amount' => ['nullable', 'numeric'],
        ]);

        $data['type'] = $data['type'] ?? 'sell';
        $data['user_id'] = auth()->id();

        try {
            $result = $service->create($data);

            // Return checkout page with sale data for receipt preview
            return Inertia::render('POS/Checkout', [
                'customers' => Customer::select('id', 'name')->where('is_active', true)->orWhere('active', 1)->limit(100)->get(),
                'settings' => $this->getPosSettings(),
                'lastSale' => [
                    'invoice_no' => $result['sale']->invoice_no,
                    'subtotal' => $result['sale']->subtotal,
                    'discount' => $result['sale']->discount,
                    'tax' => $result['sale']->tax,
                    'total' => $result['sale']->total,
                    'paid' => $result['sale']->paid,
                    'change_amount' => $result['sale']->change_amount,
                    'status' => $result['sale']->status,
                    'created_at' => $result['sale']->created_at,
                    'items' => $result['items']->map(fn ($i) => [
                        'product_name' => $i->product_name,
                        'sku' => $i->sku,
                        'qty' => $i->qty,
                        'price' => $i->price,
                        'subtotal' => $i->subtotal,
                    ]),
                    'payment' => [
                        'method' => $result['payment']->method,
                        'amount' => $result['payment']->amount,
                    ],
                    'cashier' => auth()->user()->name ?? 'Kasir',
                ],
            ]);
        } catch (\Exception $e) {
            return redirect()->back()->withErrors(['items' => $e->getMessage()])->withInput();
        }
    }

    private function getPosSettings(): array
    {
        $rows = DB::table('settings')
            ->whereNotNull('setting_key')
            ->pluck('setting_value', 'setting_key')
            ->toArray();

        return [
            'store_name' => $rows['store.name'] ?? 'TOKO POSQU PRO',
            'store_address' => $rows['store.address'] ?? '',
            'store_phone' => $rows['store.phone'] ?? '',
            'receipt_header' => $rows['receipt.header'] ?? 'Terima Kasih Telah Berbelanja',
            'receipt_footer' => $rows['receipt.footer'] ?? '',
            'printer_type' => $rows['printer.connection.type'] ?? 'Bluetooth',
            'printer_name' => $rows['printer.name'] ?? 'auto',
            'printer_mac' => $rows['printer.bluetooth.mac'] ?? '',
            'paper_width' => $rows['printer.paper.width'] ?? '80',
            'font_size' => $rows['printer.font.size'] ?? '7',
            'font_family' => $rows['printer.font.family'] ?? 'monospace',
            'margin_top' => $rows['printer.margin.top'] ?? '0',
            'margin_bottom' => $rows['printer.margin.bottom'] ?? '0',
            'margin_left' => $rows['printer.margin.left'] ?? '0',
            'spacing_line' => $rows['printer.spacing.line'] ?? '80',
            'alignment' => $rows['printer.alignment'] ?? 'left',
            'auto_print' => ($rows['printer.auto.print'] ?? 'false') === 'true',
        ];
    }
}
