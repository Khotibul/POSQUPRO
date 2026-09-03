<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Warehouse;
use Illuminate\Http\Request;

class WarehouseController extends Controller
{
    public function index(Request $request)
    {
        return Warehouse::with('branch')->when($request->branch_id, fn ($q, $v) => $q->where('branch_id', $v))->latest()->paginate(15);
    }

    public function store(Request $request)
    {
        $data = $request->validate(['branch_id' => ['required', 'exists:branches,id'], 'code' => ['required', 'string', 'unique:warehouses,code'], 'name' => ['required', 'string'], 'phone' => ['nullable', 'string'], 'address' => ['nullable', 'string'], 'active' => ['boolean']]);
        return Warehouse::create($data);
    }

    public function show(Warehouse $warehouse)
    {
        return $warehouse->load('branch');
    }

    public function update(Request $request, Warehouse $warehouse)
    {
        $data = $request->validate(['branch_id' => ['sometimes', 'exists:branches,id'], 'code' => ['sometimes', 'string', 'unique:warehouses,code,'.$warehouse->id], 'name' => ['sometimes', 'string'], 'phone' => ['nullable', 'string'], 'address' => ['nullable', 'string'], 'active' => ['boolean']]);
        $warehouse->update($data);
        return $warehouse;
    }

    public function destroy(Warehouse $warehouse)
    {
        $warehouse->delete();
        return response()->json(['message' => 'deleted']);
    }
}
