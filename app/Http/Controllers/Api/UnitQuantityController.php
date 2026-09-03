<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\UnitQuantity;
use Illuminate\Http\Request;

class UnitQuantityController extends Controller
{
    public function index()
    {
        return UnitQuantity::latest()->paginate(15);
    }

    public function store(Request $request)
    {
        $data = $request->validate(['name' => ['required', 'string'], 'symbol' => ['required', 'string', 'unique:unit_quantities,symbol'], 'description' => ['nullable', 'string']]);

        return UnitQuantity::create($data);
    }

    public function show(UnitQuantity $unitQuantity)
    {
        return $unitQuantity;
    }

    public function update(Request $request, UnitQuantity $unitQuantity)
    {
        $data = $request->validate(['name' => ['sometimes', 'string'], 'symbol' => ['sometimes', 'string', 'unique:unit_quantities,symbol,'.$unitQuantity->id], 'description' => ['nullable', 'string']]);
        $unitQuantity->update($data);

        return $unitQuantity;
    }

    public function destroy(UnitQuantity $unitQuantity)
    {
        $unitQuantity->delete();

        return response()->json(['message' => 'deleted']);
    }
}
