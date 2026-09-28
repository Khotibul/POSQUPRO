<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Supplier;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;

class SupplierController extends Controller
{
    public function index(Request $request)
    {
        return Supplier::when($request->search, fn ($q, $s) => $q->where('name', 'like', "%{$s}%"))->latest()->paginate(15);
    }

    public function store(Request $request)
    {
        $data = $request->validate(['name' => ['required', 'string'], 'email' => ['nullable', 'email'], 'phone' => ['nullable', 'string'], 'address' => ['nullable', 'string'], 'contact_person' => ['nullable', 'string'], 'is_active' => ['boolean']]);

        // Java schema requires NOT NULL unique `code`
        if (Schema::hasColumn('suppliers', 'code') && empty($data['code'])) {
            $data['code'] = 'SUP-'.strtoupper(substr(md5($data['name'].microtime()), 0, 8));
        }

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
