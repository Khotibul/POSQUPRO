<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Branch;
use Illuminate\Http\Request;

class BranchController extends Controller
{
    public function index()
    {
        return Branch::latest()->paginate(15);
    }

    public function store(Request $request)
    {
        $data = $request->validate(['code' => ['required', 'string', 'unique:branches,code'], 'name' => ['required', 'string'], 'address' => ['nullable', 'string'], 'phone' => ['nullable', 'string'], 'active' => ['boolean']]);
        return Branch::create($data);
    }

    public function show(Branch $branch)
    {
        return $branch->load('warehouses');
    }

    public function update(Request $request, Branch $branch)
    {
        $data = $request->validate(['code' => ['sometimes', 'string', 'unique:branches,code,'.$branch->id], 'name' => ['sometimes', 'string'], 'address' => ['nullable', 'string'], 'phone' => ['nullable', 'string'], 'active' => ['boolean']]);
        $branch->update($data);
        return $branch;
    }

    public function destroy(Branch $branch)
    {
        $branch->delete();
        return response()->json(['message' => 'deleted']);
    }
}
