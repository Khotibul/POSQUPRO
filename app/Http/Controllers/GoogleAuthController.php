<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Spatie\Permission\Models\Role;
use Throwable;

class GoogleAuthController extends Controller
{
    private function getRedirectUri(): string
    {
        $configUri = config('services.google.redirect_uri');

        return $configUri ? url($configUri) : route('google.callback');
    }

    public function redirect()
    {
        $clientId = config('services.google.client_id');
        $clientSecret = config('services.google.client_secret');

        if (! $clientId || ! $clientSecret) {
            return redirect('/login')->withErrors([
                'email' => 'Google OAuth belum dikonfigurasi. Silakan login manual.',
            ]);
        }

        $state = Str::random(40);
        session(['google_state' => $state]);

        $url = 'https://accounts.google.com/o/oauth2/v2/auth?'.http_build_query([
            'client_id' => $clientId,
            'redirect_uri' => $this->getRedirectUri(),
            'response_type' => 'code',
            'scope' => 'openid email profile',
            'access_type' => 'offline',
            'prompt' => 'consent',
            'state' => $state,
        ]);

        return redirect($url);
    }

    public function callback(Request $request)
    {
        if ($request->has('error')) {
            return redirect('/login')->withErrors([
                'email' => 'Login dibatalkan atau terjadi kesalahan dari Google.',
            ]);
        }

        if (! $request->has('code') || ! $request->has('state')) {
            return redirect('/login')->withErrors([
                'email' => 'Response dari Google tidak valid.',
            ]);
        }

        $expectedState = session('google_state');
        session()->forget('google_state');

        if (! $expectedState || $request->state !== $expectedState) {
            return redirect('/login')->withErrors([
                'email' => 'Autentikasi gagal (state tidak cocok). Silakan coba lagi.',
            ]);
        }

        $redirectUri = $this->getRedirectUri();

        try {
            $tokenResponse = Http::timeout(10)->asForm()->post('https://oauth2.googleapis.com/token', [
                'code' => $request->code,
                'client_id' => config('services.google.client_id'),
                'client_secret' => config('services.google.client_secret'),
                'redirect_uri' => $redirectUri,
                'grant_type' => 'authorization_code',
            ]);
        } catch (Throwable $e) {
            Log::error('Google OAuth HTTP error', ['message' => $e->getMessage()]);

            return redirect('/login')->withErrors([
                'email' => 'Gagal menghubungi server Google. Periksa koneksi internet.',
            ]);
        }

        if ($tokenResponse->failed()) {
            Log::warning('Google OAuth token exchange failed', [
                'error' => $tokenResponse->json('error', 'unknown'),
                'description' => $tokenResponse->json('error_description', ''),
                'status' => $tokenResponse->status(),
                'redirect_uri_sent' => $redirectUri,
            ]);

            return redirect('/login')->withErrors([
                'email' => 'Gagal mendapatkan token dari Google. Silakan coba lagi.',
            ]);
        }

        $accessToken = $tokenResponse->json('access_token');

        try {
            $userInfo = Http::timeout(10)->withToken($accessToken)->get('https://www.googleapis.com/oauth2/v2/userinfo');
        } catch (Throwable $e) {
            return redirect('/login')->withErrors([
                'email' => 'Gagal mengambil data profil dari Google.',
            ]);
        }

        if ($userInfo->failed()) {
            return redirect('/login')->withErrors([
                'email' => 'Gagal membaca data profil Google.',
            ]);
        }

        $googleUser = $userInfo->json();
        $email = $googleUser['email'] ?? null;
        $googleId = $googleUser['id'] ?? null;
        $name = $googleUser['name'] ?? $email;
        $avatar = $googleUser['picture'] ?? null;
        $emailVerified = $googleUser['verified_email'] ?? false;

        if (! $email || ! $googleId) {
            return redirect('/login')->withErrors([
                'email' => 'Data Google tidak lengkap.',
            ]);
        }

        if (! $emailVerified) {
            return redirect('/login')->withErrors([
                'email' => 'Email Google belum terverifikasi. Verifikasi di akun Google Anda.',
            ]);
        }

        $user = User::where('google_id', $googleId)->first();

        if (! $user) {
            $user = User::where('email', $email)->first();
        }

        if ($user) {
            $updateData = [
                'avatar' => $avatar ?? $user->avatar,
                'email_verified_at' => $user->email_verified_at ?? now(),
            ];
            if (! $user->google_id) {
                $updateData['google_id'] = $googleId;
            }
            $user->update($updateData);
        } else {
            $user = User::create([
                'name' => $name,
                'email' => $email,
                'google_id' => $googleId,
                'avatar' => $avatar,
                'email_verified_at' => now(),
                'is_active' => true,
                'password' => null,
            ]);

            if (class_exists(Role::class)) {
                $cashierRole = Role::where('name', 'Cashier')->first();
                if ($cashierRole) {
                    $user->assignRole('Cashier');
                }
            }
        }

        if (! $user->is_active) {
            return redirect('/login')->withErrors([
                'email' => 'Akun telah dinonaktifkan. Hubungi administrator.',
            ]);
        }

        Auth::login($user, true);
        $user->update(['last_login_at' => now()]);

        return redirect()->intended('/dashboard');
    }
}
