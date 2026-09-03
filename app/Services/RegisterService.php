<?php

namespace App\Services;

use App\Models\Payment;
use App\Models\Register;
use App\Models\RegisterSession;
use Illuminate\Support\Facades\DB;

class RegisterService
{
    public function paginate(array $filters = [], int $perPage = 15)
    {
        return Register::withCount('sessions')->latest()->paginate($perPage);
    }

    public function create(array $data): Register
    {
        return Register::create($data);
    }

    public function openSession(int $registerId, array $data): RegisterSession
    {
        return DB::transaction(function () use ($registerId, $data) {
            $register = Register::findOrFail($registerId);
            // Check no open session
            $openSession = $register->sessions()->where('status', 'open')->first();
            if ($openSession) {
                throw new \Exception('Register already has an open session');
            }

            return RegisterSession::create([
                'register_id' => $registerId,
                'user_id' => $data['user_id'] ?? auth()->id(),
                'opened_by' => auth()->id(),
                'opening_float' => $data['opening_float'] ?? 0,
                'status' => 'open',
                'opened_at' => now(),
                'notes' => $data['notes'] ?? null,
            ]);
        });
    }

    public function closeSession(int $sessionId, array $data): RegisterSession
    {
        return DB::transaction(function () use ($sessionId, $data) {
            $session = RegisterSession::findOrFail($sessionId);
            if ($session->status !== 'open') {
                throw new \Exception('Session is not open');
            }

            $actualCash = $data['actual_cash'] ?? 0;
            $expectedCash = $session->opening_float;

            // Add cash sales from this session
            $cashSales = Payment::whereHas('transaction', function ($q) use ($session) {
                $q->where('created_at', '>=', $session->opened_at)
                    ->where('type', 'sell')
                    ->where('status', 'completed');
            })->where('method', 'cash')->where('status', 'success')->sum('amount');

            $expectedCash += $cashSales;

            $session->update([
                'closed_by' => auth()->id(),
                'actual_cash' => $actualCash,
                'expected_cash' => $expectedCash,
                'over_short' => $actualCash - $expectedCash,
                'status' => 'closed',
                'closed_at' => now(),
                'close_notes' => $data['notes'] ?? null,
            ]);

            return $session->fresh();
        });
    }

    public function getOpenSession(int $registerId): ?RegisterSession
    {
        return Register::find($registerId)?->sessions()->where('status', 'open')->first();
    }
}
