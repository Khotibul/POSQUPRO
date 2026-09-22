<?php

namespace App\Support;

use Illuminate\Support\Facades\Hash;

class LegacyPassword
{
    private const SALT = 'posqu_salt_v1';

    /**
     * SHA-256 hash used by Java desktop (PasswordUtil::hash).
     */
    public static function sha256(string $password): string
    {
        return hash('sha256', $password.':'.self::SALT);
    }

    /**
     * Check if hash is bcrypt.
     */
    public static function isBcrypt(?string $hash): bool
    {
        if (! $hash) {
            return false;
        }

        return str_starts_with($hash, '$2y$') || str_starts_with($hash, '$2a$') || str_starts_with($hash, '$2b$');
    }

    /**
     * Verify plain password against stored hash (supports both bcrypt and legacy SHA256).
     */
    public static function verify(string $plain, ?string $hash): bool
    {
        if (! $hash) {
            return false;
        }

        // Google OAuth placeholder
        if ($hash === 'google-oauth') {
            return false;
        }

        if (self::isBcrypt($hash)) {
            return Hash::check($plain, $hash);
        }

        // Legacy SHA-256 with salt
        return hash_equals($hash, self::sha256($plain));
    }

    /**
     * Check if stored hash needs rehash to bcrypt.
     */
    public static function needsRehash(?string $hash): bool
    {
        if (! $hash || $hash === 'google-oauth') {
            return false;
        }

        return ! self::isBcrypt($hash);
    }
}
