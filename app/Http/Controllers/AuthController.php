<?php

namespace App\Http\Controllers;

use App\Models\Tenant;
use App\Models\User;
use App\Services\SubscriptionService;
use App\Services\TenantOwnerService;
use App\Support\LegacyPassword;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;

class AuthController extends Controller
{
    public function showLogin()
    {
        return Inertia::render('Auth/Login');
    }

    public function showRegister()
    {
        return Inertia::render('Auth/Register');
    }

    /**
     * Self-service registration (mirrors pos-next-js register-tenant):
     * create tenant + owner user in one transaction, then auto-login.
     */
    public function register(Request $request)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'store_name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['nullable', 'string', 'max:30'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'agree' => ['accepted'],
        ]);

        $user = DB::transaction(function () use ($validated) {
            $tenant = Tenant::create([
                'name' => $validated['store_name'],
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

        Auth::login($user);
        $request->session()->regenerate();

        if (Schema::hasColumn('users', 'last_login_at')) {
            $user->update(['last_login_at' => now()]);
        }

        return redirect('/dashboard');
    }

    public function login(Request $request)
    {
        $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $request->email)->first();

        if (! $user) {
            throw ValidationException::withMessages([
                'email' => ['Email tidak terdaftar.'],
            ]);
        }

        // Null-safe: bare Java schema has no is_active column (null = treat as active)
        if (($user->is_active ?? true) === false || ($user->active ?? true) === false) {
            throw ValidationException::withMessages([
                'email' => ['Akun Anda telah dinonaktifkan. Hubungi administrator.'],
            ]);
        }

        $hasPassword = Hash::isHashed($user->password ?? '') || Hash::isHashed($user->password_hash ?? '') || $user->password_hash === 'google-oauth';
        if (($user->google_id ?? null) && ! $hasPassword) {
            throw ValidationException::withMessages([
                'email' => ['Akun ini terdaftar via Google. Silakan gunakan tombol "Masuk dengan Google".'],
            ]);
        }

        // Support both bcrypt and legacy SHA256 (Java desktop)
        $passwordValid = LegacyPassword::verify($request->password, $user->password ?? null)
            || LegacyPassword::verify($request->password, $user->password_hash ?? null);

        if (! $passwordValid) {
            throw ValidationException::withMessages([
                'email' => ['Password salah.'],
            ]);
        }

        // Auto-migrate legacy SHA256 to bcrypt (only columns that exist)
        if (LegacyPassword::needsRehash($user->password ?? null) || LegacyPassword::needsRehash($user->password_hash ?? null)) {
            $newHash = Hash::make($request->password);
            $migrate = [];
            if (Schema::hasColumn('users', 'password')) {
                $migrate['password'] = $newHash;
            }
            // password_hash always exists on Java schema (NOT NULL)
            $migrate['password_hash'] = $newHash;
            DB::table('users')->where('id', $user->id)->update($migrate);
        }

        Auth::login($user, $request->boolean('remember'));

        $request->session()->regenerate();
        if (Schema::hasColumn('users', 'last_login_at')) {
            $request->user()->update(['last_login_at' => now()]);
        }

        return redirect()->intended('/dashboard');
    }

    public function logout(Request $request)
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect('/login');
    }
}
