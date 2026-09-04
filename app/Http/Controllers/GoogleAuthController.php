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
        $redirectUri = $this->getRedirectUri();

        if (! $clientId || ! $clientSecret) {
            return redirect('/login')->withErrors([
                'email' => 'Google OAuth belum dikonfigurasi. Silakan login manual.',
            ]);
        }

        $state = Str::random(40);
        session(['google_state' => $state]);

        Log::info('Google OAuth redirect', [
            'client_id' => substr($clientId, 0, 20).'...',
            'redirect_uri' => $redirectUri,
        ]);

        $url = 'https://accounts.google.com/o/oauth2/v2/auth?'.http_build_query([
            'client_id' => $clientId,
            'redirect_uri' => $redirectUri,
            'response_type' => 'code',
            'scope' => 'openid email profile',
            'access_type' => 'offline',
            'prompt' => 'select_account',
            'state' => $state,
        ]);

        return redirect($url);
    }

    public function callback(Request $request)
    {
        if ($request->has('error')) {
            Log::warning('Google OAuth error from Google', [
                'error' => $request->input('error'),
                'error_description' => $request->input('error_description'),
            ]);

            return redirect('/login')->withErrors([
                'email' => 'Login dibatalkan atau terjadi kesalahan: '.$request->input('error_description', $request->input('error')),
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

        Log::info('Google OAuth token exchange', [
            'redirect_uri' => $redirectUri,
        ]);

        try {
            $tokenResponse = Http::timeout(15)->asForm()->post('https://oauth2.googleapis.com/token', [
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
                'body' => $tokenResponse->body(),
            ]);

            $desc = $tokenResponse->json('error_description', '');
            $msg = 'Gagal mendapatkan token dari Google.';
            if (str_contains($desc, 'redirect_uri')) {
                $msg .= ' Redirect URI tidak cocok dengan Google Console.';
            } elseif (str_contains($desc, 'invalid_client')) {
                $msg .= ' Client ID/Secret salah atau belum dikonfigurasi.';
            } else {
                $msg .= ' '.$desc;
            }

            return redirect('/login')->withErrors(['email' => $msg]);
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
            Log::warning('Google userinfo failed', [
                'status' => $userInfo->status(),
                'body' => $userInfo->body(),
            ]);

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
                'password_hash' => 'google-oauth',
            ]);

            if (class_exists(Role::class)) {
                $cashierRole = Role::where('name', 'Cashier')->first();
                if ($cashierRole) {
                    $user->assignRole('Cashier');
                }
            }

            Log::info('Google OAuth: new user created', ['user_id' => $user->id, 'email' => $email]);
        }

        if (! $user->is_active) {
            return redirect('/login')->withErrors([
                'email' => 'Akun telah dinonaktifkan. Hubungi administrator.',
            ]);
        }

        Auth::login($user, true);
        $user->update(['last_login_at' => now()]);

        Log::info('Google OAuth: user logged in', ['user_id' => $user->id, 'email' => $email]);

        return redirect()->intended('/dashboard');
    }
}
