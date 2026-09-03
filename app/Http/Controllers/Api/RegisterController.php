<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\RegisterResource;
use App\Models\Register;
use Illuminate\Http\Request;

class RegisterController extends Controller
{
    public function index()
    {
        return RegisterResource::collection(Register::withCount('sessions')->latest()->paginate(15));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string'],
            'code' => ['required', 'string', 'unique:registers,code'],
            'description' => ['nullable', 'string'],
            'is_active' => ['boolean'],
        ]);

        return new RegisterResource(Register::create($data));
    }

    public function show(Register $register)
    {
        return new RegisterResource($register->load(['openSession' => function ($q) {
            $q->where('status', 'open')->with(['user', 'opener']);
        }]));
    }

    public function update(Request $request, Register $register)
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string'],
            'code' => ['sometimes', 'string', 'unique:registers,code,'.$register->id],
            'description' => ['nullable', 'string'],
            'is_active' => ['boolean'],
        ]);
        $register->update($data);

        return new RegisterResource($register);
    }

    public function destroy(Register $register)
    {
        $register->delete();

        return response()->json(['message' => 'deleted']);
    }
}
