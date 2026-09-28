<?php

namespace App\Http\Controllers;

use App\Models\User;
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
