<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\GoogleAuthController;
use App\Http\Controllers\InvoiceController;
use App\Http\Controllers\ParkedTransactionController;
use App\Http\Controllers\PlanController;
use App\Http\Controllers\PosController;
use App\Http\Controllers\PurchaseOrderController;
use App\Http\Controllers\RegisterController;
use App\Http\Controllers\SaasController;
use App\Http\Controllers\SettingController;
use App\Http\Controllers\StockCountController;
use App\Http\Controllers\TenantController;
use App\Http\Controllers\TransactionController;
use App\Models\Branch;
use App\Models\Category;
use App\Models\Customer;
use App\Models\InventoryHistory;
use App\Models\Product;
use App\Models\Supplier;
use App\Models\Tax;
use App\Models\Transaction;
use App\Models\TransactionItem;
use App\Models\UnitQuantity;
use App\Models\User;
use App\Models\Warehouse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;
use Inertia\Inertia;
use Spatie\Permission\Models\Role;

// Public - Landing page persis pos-next-js (hero, fitur, pricing) untuk guest, redirect ke dashboard untuk auth
Route::get('/', function () {
    if (auth()->check()) {
        return redirect('/dashboard');
    }

    return view('welcome');
});

Route::middleware('guest')->group(function () {
    Route::get('/login', [AuthController::class, 'showLogin'])->name('login');
    Route::post('/login', [AuthController::class, 'login']);

    // Google OAuth
    Route::get('/auth/google/redirect', [GoogleAuthController::class, 'redirect'])->name('google.redirect');
    Route::get('/auth/google/callback', [GoogleAuthController::class, 'callback'])->name('google.callback');
});

// Protected (mirip pos-next-js (private) group - requires auth)
Route::middleware('auth')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout'])->name('logout');

    Route::get('/dashboard', [DashboardController::class, 'index'])->name('dashboard');

    // POS - Kasir (role: Cashier, Super Admin, Admin) - menu page, bukan popup (hemat memori)
    Route::get('/pos', [PosController::class, 'index'])->name('pos.index');
    Route::get('/pos/checkout', [PosController::class, 'checkoutPage'])->name('pos.checkout.page');
    Route::get('/pos/park', [PosController::class, 'parkPage'])->name('pos.park.page');
    Route::post('/pos/park', [PosController::class, 'park'])->name('pos.park');
    Route::delete('/pos/park/{id}', [PosController::class, 'destroyPark'])->name('pos.park.destroy');
    Route::post('/pos/checkout', [PosController::class, 'checkout'])->name('pos.checkout');

    // Products - support search/filter params
    Route::get('/products', function (Request $request) {
        $products = Product::with(['category', 'unitQuantity', 'tax', 'supplier'])
            ->when($request->search, fn ($q, $s) => $q->where(function ($qq) use ($s) {
                $qq->where('name', 'like', "%{$s}%")
                    ->orWhere('sku', 'like', "%{$s}%")
                    ->orWhere('barcode', 'like', "%{$s}%")
                    ->orWhere('category', 'like', "%{$s}%");
            }))
            ->when($request->category_id, fn ($q, $v) => $q->where('category_id', $v))
            ->when($request->type, fn ($q, $v) => $q->where('type', $v))
            ->latest()
            ->paginate(15)
            ->withQueryString();

        return Inertia::render('Products/Index', [
            'products' => $products,
            'categories' => Category::all(),
            'units' => UnitQuantity::all(),
            'taxes' => Tax::all(),
            'suppliers' => Supplier::all(),
            'filters' => $request->only(['search', 'category_id', 'type']),
        ]);
    })->name('products.index');

    // Customers
    Route::get('/customers', function () {
        return Inertia::render('Customers/Index', [
            'customers' => Customer::latest()->paginate(15),
        ]);
    })->name('customers.index');

    // Inventory - tampil sesuai DB (jika inventory_histories kosong, tampilkan stock_movements Java)
    Route::get('/inventory', function () {
        $histories = InventoryHistory::with(['product', 'user'])->latest()->paginate(15);
        if ($histories->total() === 0 && Schema::hasTable('stock_movements')) {
            $histories = DB::table('stock_movements')->orderByDesc('id')->paginate(15);
            $histories->setCollection($histories->getCollection()->map(fn ($m) => (array) $m + ['product' => null, 'user' => null, 'type' => strtolower($m->movement_type), 'quantity' => $m->qty]));
        }

        return Inertia::render('Inventory/Index', [
            'products' => Product::with(['category', 'unitQuantity'])->latest()->paginate(15),
            'histories' => $histories,
        ]);
    })->name('inventory.index');

    // Transactions
    Route::get('/transactions', [TransactionController::class, 'index'])->name('transactions.index');

    // Reports
    Route::get('/reports', function () {
        return Inertia::render('Reports/Index', [
            'stats' => [
                'today_revenue' => Transaction::whereDate('created_at', today())->sum('total'),
                'today_transactions' => Transaction::whereDate('created_at', today())->count(),
                'month_revenue' => Transaction::whereMonth('created_at', now()->month)->sum('total'),
                'low_stock_count' => Product::whereColumn('stock', '<=', 'min_stock')->count(),
            ],
            'salesData' => Transaction::whereDate('created_at', '>=', now()->subDays(30))
                ->where('type', 'sell')->where('status', 'completed')
                ->selectRaw('DATE(created_at) as date, SUM(total) as total, COUNT(*) as count')
                ->groupByRaw('DATE(created_at)')
                ->orderBy('date')
                ->get(),
            'topProducts' => TransactionItem::select('product_id', DB::raw('SUM(quantity) as qty'), DB::raw('SUM(subtotal) as revenue'))
                ->whereHas('transaction', fn ($q) => $q->where('type', 'sell')->where('status', 'completed')->whereDate('created_at', '>=', now()->subDays(30)))
                ->groupBy('product_id')->orderByDesc('qty')->with('product')->limit(10)->get(),
            'paymentBreakdown' => Transaction::join('payments', 'payments.transaction_id', '=', 'transactions.id')
                ->whereDate('transactions.created_at', today())
                ->select('payments.method', DB::raw('SUM(payments.amount) as total'))
                ->groupBy('payments.method')->get(),
        ]);
    })->name('reports.index');

    // Users & RBAC
    Route::get('/users', function () {
        return Inertia::render('Users/Index', [
            'users' => User::with('roles')->paginate(15),
            'roles' => Role::all(),
        ]);
    })->name('users.index');

    Route::get('/suppliers', function () {
        return Inertia::render('Suppliers/Index', [
            'suppliers' => Supplier::paginate(15),
        ]);
    })->name('suppliers.index');

    // New pos-next-js features
    Route::get('/register', [RegisterController::class, 'index'])->name('register.index');
    Route::get('/parked-transactions', [ParkedTransactionController::class, 'index'])->name('parked-transactions.index');
    Route::get('/purchase-orders', [PurchaseOrderController::class, 'index'])->name('purchase-orders.index');
    Route::get('/stock-counts', [StockCountController::class, 'index'])->name('stock-counts.index');
    Route::get('/settings', [SettingController::class, 'index'])->name('settings.index');
    Route::post('/settings', [SettingController::class, 'updateGroup'])->name('settings.updateGroup');
    Route::post('/settings/tax', [SettingController::class, 'storeTax'])->name('settings.storeTax');
    Route::put('/settings/tax/{id}', [SettingController::class, 'updateTax'])->name('settings.updateTax');
    Route::delete('/settings/tax/{id}', [SettingController::class, 'destroyTax'])->name('settings.destroyTax');
    Route::put('/settings/payment-method/{id}', [SettingController::class, 'updatePaymentMethod'])->name('settings.updatePaymentMethod');

    // Master data - tampil sesuai DB posqu_pro_desktop (dedicated pages)
    Route::get('/categories', function () {
        $cats = DB::table('product_categories')->select('id', 'name')->get()->map(fn ($c) => ['id' => $c->id, 'name' => $c->name, 'type' => 'Java']);
        $cats2 = Category::select('id', 'name')->get()->map(fn ($c) => ['id' => $c->id, 'name' => $c->name, 'type' => 'Laravel']);
        $all = $cats->merge($cats2);

        return Inertia::render('Categories/Index', ['categories' => Category::paginate(15), 'allCategories' => $all]);
    })->name('categories.index');
    Route::get('/units', function () {
        $units = DB::table('units')->select('id', 'name')->get();
        $uqs = UnitQuantity::select('id', 'name', 'symbol')->get();

        return Inertia::render('Units/Index', ['units' => UnitQuantity::paginate(15), 'allUnits' => $units, 'unitQuantities' => $uqs]);
    })->name('units.index');
    Route::get('/taxes', fn () => Inertia::render('Taxes/Index', ['taxes' => Tax::paginate(15)]))->name('taxes.index');
    Route::get('/branches', fn () => Inertia::render('Branches/Index', ['branches' => Branch::with('warehouses')->paginate(15)]))->name('branches.index');
    Route::get('/warehouses', function () {
        return Inertia::render('Warehouses/Index', [
            'warehouses' => Warehouse::with('branch')->paginate(15),
            'branches' => Branch::select('id', 'name', 'code')->get(),
        ]);
    })->name('warehouses.index');

    // ═══════════════════════════════════════════════════════════════
    // SaaS Management - Super Admin Owner
    // ═══════════════════════════════════════════════════════════════
    Route::get('/saas', [SaasController::class, 'dashboard'])->name('saas.dashboard');
    Route::get('/tenants', [TenantController::class, 'index'])->name('tenants.index');
    Route::post('/tenants', [TenantController::class, 'store'])->name('tenants.store');
    Route::get('/tenants/{tenant}', [TenantController::class, 'show'])->name('tenants.show');
    Route::put('/tenants/{tenant}', [TenantController::class, 'update'])->name('tenants.update');
    Route::delete('/tenants/{tenant}', [TenantController::class, 'destroy'])->name('tenants.destroy');
    Route::post('/tenants/{tenant}/suspend', [TenantController::class, 'suspend'])->name('tenants.suspend');
    Route::post('/tenants/{tenant}/activate', [TenantController::class, 'activate'])->name('tenants.activate');

    Route::get('/billing/plans', [PlanController::class, 'index'])->name('plans.index');
    Route::post('/billing/plans', [PlanController::class, 'store'])->name('plans.store');
    Route::put('/billing/plans/{plan}', [PlanController::class, 'update'])->name('plans.update');
    Route::delete('/billing/plans/{plan}', [PlanController::class, 'destroy'])->name('plans.destroy');

    Route::get('/billing/invoices', [InvoiceController::class, 'index'])->name('invoices.index');
    Route::post('/billing/invoices', [InvoiceController::class, 'store'])->name('invoices.store');
    Route::post('/billing/invoices/{invoice}/pay', [InvoiceController::class, 'markPaid'])->name('invoices.markPaid');
    Route::delete('/billing/invoices/{invoice}', [InvoiceController::class, 'destroy'])->name('invoices.destroy');
});
