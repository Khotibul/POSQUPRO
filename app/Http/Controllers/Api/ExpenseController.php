<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Expense;
use Illuminate\Http\Request;

class ExpenseController extends Controller
{
    public function index(Request $request)
    {
        return Expense::with(['branch', 'user'])
            ->when($request->search, fn ($q, $s) => $q->where('description', 'like', "%{$s}%")->orWhere('category', 'like', "%{$s}%"))
            ->when($request->branch_id, fn ($q, $v) => $q->where('branch_id', $v))
            ->latest()->paginate(15);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'branch_id' => ['nullable', 'integer', 'exists:branches,id'],
            'shift_id' => ['nullable', 'integer', 'exists:shifts,id'],
            'category' => ['required', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:255'],
            'amount' => ['required', 'integer', 'min:1'],
        ]);
        $data['user_id'] = $request->user()->id;

        return Expense::create($data)->load(['branch', 'user']);
    }

    public function show(Expense $expense)
    {
        return $expense->load(['branch', 'user']);
    }

    public function update(Request $request, Expense $expense)
    {
        $data = $request->validate([
            'branch_id' => ['nullable', 'integer', 'exists:branches,id'],
            'shift_id' => ['nullable', 'integer', 'exists:shifts,id'],
            'category' => ['sometimes', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:255'],
            'amount' => ['sometimes', 'integer', 'min:1'],
        ]);
        $expense->update($data);

        return $expense->load(['branch', 'user']);
    }

    public function destroy(Expense $expense)
    {
        $expense->delete();

        return response()->json(['message' => 'deleted']);
    }
}
