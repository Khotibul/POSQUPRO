<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Supplier;
use Illuminate\Http\Request;

class SupplierController extends Controller
{
    public function index(Request $request)
    {
        return Supplier::when($request->search, fn ($q, $s) => $q->where('name', 'like', "%{$s}%"))->latest()->paginate(15);
    }

    public function store(Request $request)
    {
        $data = $request->validate(['name' => ['required', 'string'], 'email' => ['nullable', 'email'], 'phone' => ['nullable', 'string'], 'address' => ['nullable', 'string'], 'contact_person' => ['nullable', 'string'], 'is_active' => ['boolean']]);

        return Supplier::create($data);
    }

    public function show(Supplier $supplier)
    {
        return $supplier;
    }

    public function update(Request $request, Supplier $supplier)
    {
        $data = $request->validate(['name' => ['sometimes', 'string'], 'email' => ['nullable', 'email'], 'phone' => ['nullable', 'string'], 'address' => ['nullable', 'string'], 'contact_person' => ['nullable', 'string'], 'is_active' => ['boolean']]);
        $supplier->update($data);

        return $supplier;
    }

    public function destroy(Supplier $supplier)
    {
        $supplier->delete();

        return response()->json(['message' => 'deleted']);
    }
}
