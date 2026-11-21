<?php

use App\Http\Controllers\Api\ActivityLogController;
use App\Http\Controllers\Api\BillingController as ApiBillingController;
use App\Http\Controllers\Api\BranchController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\ExpenseController;
use App\Http\Controllers\Api\FinanceController;
use App\Http\Controllers\Api\InventoryHistoryController;
use App\Http\Controllers\Api\InvoiceController;
use App\Http\Controllers\Api\IpaymuController;
use App\Http\Controllers\Api\LicenseController;
use App\Http\Controllers\Api\ParkedTransactionController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\PlanController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\PurchaseOrderController;
use App\Http\Controllers\Api\RegisterController;
use App\Http\Controllers\Api\RegisterSessionController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\SaasController;
use App\Http\Controllers\Api\SettingController;
use App\Http\Controllers\Api\StockCountController;
use App\Http\Controllers\Api\SupplierController;
use App\Http\Controllers\Api\SupplierInvoiceController;
use App\Http\Controllers\Api\TaxController;
use App\Http\Controllers\Api\TenantController;
use App\Http\Controllers\Api\TransactionController;
use App\Http\Controllers\Api\UnitQuantityController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\WarehouseController;
use App\Models\Tenant;
use App\Models\User;
use App\Services\PlanService;
use App\Services\SubscriptionService;
use App\Services\TenantOwnerService;
use App\Support\LegacyPassword;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;

Route::name('api.')->group(function () {
    Route::get('/health', fn () => ['status' => 'ok', 'app' => 'POSQUPRO']);

    // iPaymu webhook (signature-verified, no auth/CSRF)
    Route::post('/ipaymu/callback', [IpaymuController::class, 'callback']);

    // Desktop (Java SaaSClient) license + monitoring endpoints, X-API-Key auth
    Route::post('/license/validate', [LicenseController::class, 'validate']);
    Route::post('/monitoring/update', [LicenseController::class, 'monitoring']);
    Route::post('/payment/update', [LicenseController::class, 'payment']);

    // Mobile Auth (Sanctum token-based)
    // Public self-service register: tenant + owner user, returns same shape as login
    Route::post('/v1/register', function (Request $request) {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'tenant_name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['nullable', 'string', 'max:30'],
            'password' => ['required', 'string', 'min:8'],
        ]);

        $user = DB::transaction(function () use ($validated) {
            $tenant = Tenant::create([
                'name' => $validated['tenant_name'],
                'email' => $validated['email'],
                'phone' => $validated['phone'] ?? null,
                'status' => 'trial',
            ]);

            [$owner] = app(TenantOwnerService::class)->create($tenant, [
                'name' => $validated['name'],
                'email' => $validated['email'],
                'password' => $validated['password'],
            ]);

            // Demo 30 hari dengan seluruh fitur terbuka.
            app(SubscriptionService::class)->startTrial($tenant);

            return $owner;
        });

        $token = $user->createToken('mobile-app')->plainTextToken;
        $tenant = ($user->tenant_id ?? null) ? $user->tenant()->with('plan')->first() : null;

        return response()->json([
            'token' => $token,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
                'avatar' => $user->avatar ?? null,
                'tenant_id' => $user->tenant_id ?? null,
            ],
            'tenant' => $tenant ? [
                'id' => $tenant->id,
                'name' => $tenant->name,
                'slug' => $tenant->slug,
                'status' => $tenant->status,
                'license_code' => $tenant->license_code ?? null,
                'plan' => $tenant->plan ? ['id' => $tenant->plan->id, 'name' => $tenant->plan->name] : null,
                'trial_ends_at' => $tenant->trial_ends_at?->toIso8601String(),
                'subscription' => app(PlanService::class)->setTenant($tenant)->getSubscriptionSummary(),
            ] : null,
        ], 201);
    });

    Route::post('/v1/login', function (Request $request) {
        $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $request->email)->first();

        if (! $user) {
            return response()->json(['message' => 'Email atau password salah.'], 401);
        }

        $plain = $request->password;
        $valid = LegacyPassword::verify($plain, $user->password) || LegacyPassword::verify($plain, $user->password_hash) || Hash::check($plain, $user->getAuthPassword());
        if (! $valid) {
            return response()->json(['message' => 'Email atau password salah.'], 401);
        }

        // Auto-migrate legacy SHA256 to bcrypt on successful login (only columns that exist)
        if (LegacyPassword::needsRehash($user->password ?? null) || LegacyPassword::needsRehash($user->password_hash ?? null)) {
            $newHash = Hash::make($plain);
            $migrate = ['password_hash' => $newHash];
            if (Schema::hasColumn('users', 'password')) {
                $migrate['password'] = $newHash;
            }
            DB::table('users')->where('id', $user->id)->update($migrate);
        }

        if (($user->is_active ?? true) === false || ($user->active ?? true) === false) {
            return response()->json(['message' => 'Akun telah dinonaktifkan.'], 403);
        }

        // Super Admin / OWNER hanya via Website (Laravel web), tidak via API/Mobile/Desktop
        $role = strtoupper(trim($user->role ?? ''));
        if ($role === 'OWNER') {
            // Check if user has Super Admin Spatie role
            $isSuperAdmin = method_exists($user, 'hasRole') && $user->hasRole('Super Admin');
            if ($isSuperAdmin || $role === 'OWNER') {
                return response()->json(['message' => 'Akun Super Admin hanya dapat login melalui Website. Silakan buka POSQUPRO via browser.'], 403);
            }
        }

        $token = $user->createToken('mobile-app')->plainTextToken;

        $tenant = ($user->tenant_id ?? null) ? $user->tenant()->with('plan')->first() : null;

        return response()->json([
            'token' => $token,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
                'avatar' => $user->avatar ?? null,
                'tenant_id' => $user->tenant_id ?? null,
            ],
            'tenant' => $tenant ? [
                'id' => $tenant->id,
                'name' => $tenant->name,
                'slug' => $tenant->slug,
                'status' => $tenant->status,
                'license_code' => $tenant->license_code ?? null,
                'plan' => $tenant->plan ? ['id' => $tenant->plan->id, 'name' => $tenant->plan->name] : null,
                'trial_ends_at' => $tenant->trial_ends_at?->toIso8601String(),
                'subscription' => app(PlanService::class)->setTenant($tenant)->getSubscriptionSummary(),
            ] : null,
        ]);
    });

    Route::post('/v1/logout', function (Request $request) {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out']);
    })->middleware('auth:sanctum');

    // Sanctum authenticated user
    Route::middleware('auth:sanctum')->get('/user', function (Request $request) {
        return $request->user()->load('roles', 'permissions');
    });

    // Subscription status + billing stay reachable when a trial/plan has expired,
    // so mobile and desktop clients can show the expiry screen and pay.
    Route::prefix('v1')->middleware('auth:sanctum')->group(function () {
        Route::get('subscription', function (Request $request) {
            $tenant = $request->user()->tenant;
            if (! $tenant) {
                return response()->json(['subscription' => null, 'limits' => null]);
            }

            $planService = app(PlanService::class)->setTenant($tenant);

            return response()->json([
                'status' => $tenant->status,
                'subscription' => $planService->getSubscriptionSummary(),
                'plan' => $tenant->plan ? [
                    'id' => $tenant->plan->id,
                    'name' => $tenant->plan->name,
                    'slug' => $tenant->plan->slug,
                ] : null,
                'limits' => $planService->getLimitsSummary(),
                'features' => $planService->getFeatures(),
                'days_remaining' => app(SubscriptionService::class)->daysRemaining($tenant),
            ]);
        });

        Route::get('billing', [ApiBillingController::class, 'index']);
        Route::post('billing/checkout', [ApiBillingController::class, 'checkout']);
    });

    // POSQUPRO API v1 - mirrors pos-next-js protected routes (requires auth:sanctum)
    Route::prefix('v1')->middleware(['auth:sanctum', 'subscription.active'])->group(function () {
        Route::apiResource('users', UserController::class)->middleware('plan.feature:users');
        Route::apiResource('customers', CustomerController::class)->middleware('plan.feature:customers');
        Route::apiResource('suppliers', SupplierController::class)->middleware('plan.feature:suppliers');
        Route::apiResource('categories', CategoryController::class);
        Route::apiResource('unit-quantities', UnitQuantityController::class);
        Route::apiResource('taxes', TaxController::class);
        Route::apiResource('products', ProductController::class);
        Route::post('products/{product}/photo', [ProductController::class, 'uploadPhoto']);
        Route::post('products/{product}/generate-label', [ProductController::class, 'generateLabelPhoto']);
        Route::apiResource('transactions', TransactionController::class)->middleware('plan.feature:pos');
        Route::apiResource('payments', PaymentController::class);
        Route::apiResource('expenses', ExpenseController::class)->middleware('plan.feature:expenses');
        Route::apiResource('inventory-histories', InventoryHistoryController::class);

        // New pos-next-js features
        Route::apiResource('parked-transactions', ParkedTransactionController::class);
        Route::post('parked-transactions/{id}/restore', [ParkedTransactionController::class, 'restore']);
        Route::apiResource('registers', RegisterController::class);
        Route::apiResource('register-sessions', RegisterSessionController::class)->only(['index']);
        Route::post('register-sessions/open', [RegisterSessionController::class, 'open']);
        Route::post('register-sessions/{session}/close', [RegisterSessionController::class, 'close']);
        Route::get('register-sessions/current/{register}', [RegisterSessionController::class, 'current']);

        Route::middleware('plan.feature:purchase_orders')->group(function () {
            Route::apiResource('purchase-orders', PurchaseOrderController::class);
            Route::post('purchase-orders/{purchaseOrder}/receive', [PurchaseOrderController::class, 'receive']);
            Route::apiResource('supplier-invoices', SupplierInvoiceController::class);
        });

        Route::middleware('plan.feature:stock_counts')->group(function () {
            Route::apiResource('stock-counts', StockCountController::class);
            Route::post('stock-counts/{stockCount}/start', [StockCountController::class, 'start']);
            Route::post('stock-counts/{stockCount}/record', [StockCountController::class, 'record']);
            Route::post('stock-counts/{stockCount}/approve', [StockCountController::class, 'approve']);
            Route::post('stock-counts/{stockCount}/post', [StockCountController::class, 'post']);
        });

        Route::apiResource('activity-logs', ActivityLogController::class)->only(['index'])->middleware('plan.feature:reports');
        Route::apiResource('branches', BranchController::class)->middleware('plan.feature:multi_branch');
        Route::apiResource('warehouses', WarehouseController::class)->middleware('plan.feature:multi_branch');
        Route::apiResource('settings', SettingController::class);
        Route::get('settings/public', [SettingController::class, 'public']);
        Route::get('settings/group/{group}', [SettingController::class, 'group']);

        Route::middleware('plan.feature:reports')->group(function () {
            Route::get('finance/summary', [FinanceController::class, 'summary']);
            Route::get('reports/sales', [ReportController::class, 'sales']);
            Route::get('reports/inventory', [ReportController::class, 'inventory']);
        });


        // SaaS management (mirrors web Saas/Tenant/Plan/Invoice controllers, JSON for mobile)
        Route::get('saas/dashboard', [SaasController::class, 'dashboard']);
        Route::apiResource('tenants', TenantController::class);
        Route::post('tenants/{tenant}/suspend', [TenantController::class, 'suspend']);
        Route::post('tenants/{tenant}/activate', [TenantController::class, 'activate']);
        Route::apiResource('plans', PlanController::class);
        Route::apiResource('invoices', InvoiceController::class)->except(['update']);
        Route::post('invoices/{invoice}/pay', [InvoiceController::class, 'markPaid']);
    });
});
