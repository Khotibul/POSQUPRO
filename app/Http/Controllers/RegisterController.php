<?php

namespace App\Http\Controllers;

use App\Models\Register;
use App\Models\RegisterSession;
use Inertia\Inertia;

class RegisterController extends Controller
{
    public function index()
    {
        $registers = Register::with(['sessions' => function ($q) {
            $q->where('status', 'open')->with(['user', 'opener']);
        }])->latest()->paginate(15);

        $currentSession = RegisterSession::where('status', 'open')->with(['register', 'user', 'opener'])->first();

        return Inertia::render('Register/Index', [
            'registers' => $registers,
            'currentSession' => $currentSession,
        ]);
    }
}
