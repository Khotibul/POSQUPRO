<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\RegisterSessionResource;
use App\Models\RegisterSession;
use App\Services\RegisterService;
use Illuminate\Http\Request;

class RegisterSessionController extends Controller
{
    public function __construct(protected RegisterService $service) {}

    public function index()
    {
        return RegisterSessionResource::collection(RegisterSession::with(['register', 'user', 'opener', 'closer'])->latest()->paginate(15));
    }

    public function open(Request $request)
    {
        $data = $request->validate([
            'register_id' => ['required', 'exists:registers,id'],
            'opening_float' => ['required', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
        ]);

        return new RegisterSessionResource($this->service->openSession($data['register_id'], $data));
    }

    public function close(Request $request, RegisterSession $registerSession)
    {
        $data = $request->validate([
            'actual_cash' => ['required', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
        ]);

        return new RegisterSessionResource($this->service->closeSession($registerSession->id, $data));
    }

    public function current(Request $request, int $registerId)
    {
        $session = $this->service->getOpenSession($registerId);

        return $session ? new RegisterSessionResource($session) : response()->json(null);
    }
}
