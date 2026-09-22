<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Support\LegacyPassword;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
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

        if ($user->is_active === false || $user->active === false) {
            throw ValidationException::withMessages([
                'email' => ['Akun Anda telah dinonaktifkan. Hubungi administrator.'],
            ]);
        }

        $hasPassword = Hash::isHashed($user->password ?? '') || Hash::isHashed($user->password_hash ?? '') || $user->password_hash === 'google-oauth';
        if ($user->google_id && ! $hasPassword) {
            throw ValidationException::withMessages([
                'email' => ['Akun ini terdaftar via Google. Silakan gunakan tombol "Masuk dengan Google".'],
            ]);
        }

        // Support both bcrypt and legacy SHA256 (Java desktop) - Auth::attempt only checks bcrypt via getAuthPassword()
        $passwordValid = false;
        $plain = $request->password;
        // Try Laravel native (password column bcrypt)
        if (LegacyPassword::verify($plain, $user->password) || LegacyPassword::verify($plain, $user->password_hash)) {
            $passwordValid = true;
            // Auto-migrate legacy SHA256 to bcrypt if needed
            if (LegacyPassword::needsRehash($user->password) || LegacyPassword::needsRehash($user->password_hash)) {
                $newHash = Hash::make($plain);
                DB::table('users')->where('id', $user->id)->update([
                    'password' => $newHash,
                    'password_hash' => $newHash,
                ]);
            }
        }

        if (! $passwordValid) {
            throw ValidationException::withMessages([
                'email' => ['Password salah.'],
            ]);
        }

        Auth::login($user, $request->boolean('remember'));

        $request->session()->regenerate();
        $request->user()->update(['last_login_at' => now()]);

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
