<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Tax;
use Illuminate\Http\Request;

class TaxController extends Controller
{
    public function index()
    {
        return Tax::latest()->paginate(15);
    }

    public function store(Request $request)
    {
        $data = $request->validate(['name' => ['required', 'string'], 'rate' => ['required', 'numeric', 'min:0', 'max:100'], 'is_active' => ['boolean']]);

        return Tax::create($data);
    }

    public function show(Tax $tax)
    {
        return $tax;
    }

    public function update(Request $request, Tax $tax)
    {
        $data = $request->validate(['name' => ['sometimes', 'string'], 'rate' => ['sometimes', 'numeric', 'min:0', 'max:100'], 'is_active' => ['boolean']]);
        $tax->update($data);

        return $tax;
    }

    public function destroy(Tax $tax)
    {
        $tax->delete();

        return response()->json(['message' => 'deleted']);
    }
}
