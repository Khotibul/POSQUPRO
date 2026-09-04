<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class GoogleAuthController extends Controller
{
    public function redirect()
    {
        $clientId = config('services.google.client_id');
        $redirectUri = route('google.callback');
        $scopes = urlencode('openid email profile');
        $state = Str::random(40);

        session(['google_state' => $state]);

        $url = 'https://accounts.google.com/o/oauth2/v2/auth?'.http_build_query([
            'client_id' => $clientId,
            'redirect_uri' => $redirectUri,
            'response_type' => 'code',
            'scope' => $scopes,
            'access_type' => 'offline',
            'prompt' => 'consent',
            'state' => $state,
        ]);

        return redirect($url);
    }

    public function callback(Request $request)
    {
        $request->validate([
            'code' => 'required|string',
            'state' => 'required|string',
        ]);

        if ($request->state !== session('google_state')) {
            return redirect('/login')->withErrors(['email' => 'Autentikasi gagal. Silakan coba lagi.']);
        }

        session()->forget('google_state');

        $tokenResponse = Http::asForm()->post('https://oauth2.googleapis.com/token', [
            'code' => $request->code,
            'client_id' => config('services.google.client_id'),
            'client_secret' => config('services.google.client_secret'),
            'redirect_uri' => route('google.callback'),
            'grant_type' => 'authorization_code',
        ]);

        if ($tokenResponse->failed()) {
            return redirect('/login')->withErrors(['email' => 'Gagal mendapatkan token Google.']);
        }

        $accessToken = $tokenResponse->json('access_token');

        $userInfo = Http::withToken($accessToken)->get('https://www.googleapis.com/oauth2/v2/userinfo');

        if ($userInfo->failed()) {
            return redirect('/login')->withErrors(['email' => 'Gagal mendapatkan data akun Google.']);
        }

        $googleUser = $userInfo->json();
        $email = $googleUser['email'] ?? null;
        $googleId = $googleUser['id'] ?? null;
        $name = $googleUser['name'] ?? $email;
        $avatar = $googleUser['picture'] ?? null;
        $emailVerified = $googleUser['verified_email'] ?? false;

        if (! $email || ! $emailVerified) {
            return redirect('/login')->withErrors(['email' => 'Email Google harus terverifikasi.']);
        }

        $user = User::where('google_id', $googleId)
            ->orWhere('email', $email)
            ->first();

        if ($user) {
            $user->update([
                'google_id' => $googleId,
                'email_verified_at' => $user->email_verified_at ?? now(),
                'avatar' => $avatar ?? $user->avatar,
            ]);
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

            $user->assignRole('Cashier');
        }

        Auth::login($user, true);
        $user->update(['last_login_at' => now()]);

        return redirect()->intended('/dashboard');
    }
}
