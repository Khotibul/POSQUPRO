<?php

use App\Http\Controllers\Api\ActivityLogController;
use App\Http\Controllers\Api\BranchController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\FinanceController;
use App\Http\Controllers\Api\InventoryHistoryController;
use App\Http\Controllers\Api\ParkedTransactionController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\PurchaseOrderController;
use App\Http\Controllers\Api\RegisterController;
use App\Http\Controllers\Api\RegisterSessionController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\SettingController;
use App\Http\Controllers\Api\StockCountController;
use App\Http\Controllers\Api\SupplierController;
use App\Http\Controllers\Api\SupplierInvoiceController;
use App\Http\Controllers\Api\TaxController;
use App\Http\Controllers\Api\TransactionController;
use App\Http\Controllers\Api\UnitQuantityController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\WarehouseController;
use App\Models\User;
use App\Support\LegacyPassword;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => ['status' => 'ok', 'app' => 'POSQUPRO']);

// Mobile Auth (Sanctum token-based)
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

    // Auto-migrate legacy SHA256 to bcrypt on successful login
    if (LegacyPassword::needsRehash($user->password) || LegacyPassword::needsRehash($user->password_hash)) {
        $newHash = Hash::make($plain);
        DB::table('users')->where('id', $user->id)->update([
            'password' => $newHash,
            'password_hash' => $newHash,
        ]);
    }

    if ($user->is_active === false || $user->active === false) {
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

    return response()->json([
        'token' => $token,
        'user' => [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role,
            'avatar' => $user->avatar,
        ],
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

// POSQUPRO API v1 - mirrors pos-next-js protected routes (requires auth:sanctum)
Route::prefix('v1')->middleware('auth:sanctum')->group(function () {
    Route::apiResource('users', UserController::class);
    Route::apiResource('customers', CustomerController::class);
    Route::apiResource('suppliers', SupplierController::class);
    Route::apiResource('categories', CategoryController::class);
    Route::apiResource('unit-quantities', UnitQuantityController::class);
    Route::apiResource('taxes', TaxController::class);
    Route::apiResource('products', ProductController::class);
    Route::apiResource('transactions', TransactionController::class);
    Route::apiResource('payments', PaymentController::class);
    Route::apiResource('inventory-histories', InventoryHistoryController::class);

    // New pos-next-js features
    Route::apiResource('parked-transactions', ParkedTransactionController::class);
    Route::post('parked-transactions/{id}/restore', [ParkedTransactionController::class, 'restore']);
    Route::apiResource('registers', RegisterController::class);
    Route::apiResource('register-sessions', RegisterSessionController::class)->only(['index']);
    Route::post('register-sessions/open', [RegisterSessionController::class, 'open']);
    Route::post('register-sessions/{session}/close', [RegisterSessionController::class, 'close']);
    Route::get('register-sessions/current/{register}', [RegisterSessionController::class, 'current']);

    Route::apiResource('purchase-orders', PurchaseOrderController::class);
    Route::post('purchase-orders/{purchaseOrder}/receive', [PurchaseOrderController::class, 'receive']);
    Route::apiResource('supplier-invoices', SupplierInvoiceController::class);

    Route::apiResource('stock-counts', StockCountController::class);
    Route::post('stock-counts/{stockCount}/start', [StockCountController::class, 'start']);
    Route::post('stock-counts/{stockCount}/record', [StockCountController::class, 'record']);
    Route::post('stock-counts/{stockCount}/approve', [StockCountController::class, 'approve']);
    Route::post('stock-counts/{stockCount}/post', [StockCountController::class, 'post']);

    Route::apiResource('activity-logs', ActivityLogController::class)->only(['index']);
    Route::apiResource('branches', BranchController::class);
    Route::apiResource('warehouses', WarehouseController::class);
    Route::apiResource('settings', SettingController::class);
    Route::get('settings/public', [SettingController::class, 'public']);
    Route::get('settings/group/{group}', [SettingController::class, 'group']);

    Route::get('finance/summary', [FinanceController::class, 'summary']);
    Route::get('reports/sales', [ReportController::class, 'sales']);
    Route::get('reports/inventory', [ReportController::class, 'inventory']);
});
