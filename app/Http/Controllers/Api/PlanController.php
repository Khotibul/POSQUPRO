<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Plan;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class PlanController extends Controller
{
    public function index()
    {
        return Plan::orderBy('sort_order')->get();
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'slug' => 'nullable|string|max:255|unique:plans,slug',
            'description' => 'nullable|string',
            'price' => 'required|numeric|min:0',
            'price_yearly' => 'nullable|numeric|min:0',
            'trial_days' => 'nullable|integer|min:0',
            'max_users' => 'required|integer|min:0',
            'max_products' => 'required|integer|min:0',
            'max_customers' => 'nullable|integer|min:0',
            'max_transactions_per_month' => 'nullable|integer|min:0',
            'max_branches' => 'required|integer|min:0',
            'features' => 'nullable|array',
            'features.*' => 'string|in:'.implode(',', array_keys(Plan::FEATURE_LABELS)),
            'is_active' => 'boolean',
            'sort_order' => 'nullable|integer|min:0',
        ]);

        if (empty($validated['slug'])) {
            $validated['slug'] = Str::slug($validated['name']);
        }

        return Plan::create($validated);
    }

    public function show(Plan $plan)
    {
        return $plan->loadCount('tenants');
    }

    public function update(Request $request, Plan $plan)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'price' => 'required|numeric|min:0',
            'price_yearly' => 'nullable|numeric|min:0',
            'trial_days' => 'nullable|integer|min:0',
            'max_users' => 'required|integer|min:0',
            'max_products' => 'required|integer|min:0',
            'max_customers' => 'nullable|integer|min:0',
            'max_transactions_per_month' => 'nullable|integer|min:0',
            'max_branches' => 'required|integer|min:0',
            'features' => 'nullable|array',
            'features.*' => 'string|in:'.implode(',', array_keys(Plan::FEATURE_LABELS)),
            'is_active' => 'boolean',
            'sort_order' => 'nullable|integer|min:0',
        ]);

        $plan->update($validated);

        return $plan;
    }

    public function destroy(Plan $plan)
    {
        if ($plan->subscriptions()->exists()) {
            return response()->json(['message' => 'Paket tidak bisa dihapus karena masih ada subscriber'], 422);
        }

        $plan->delete();

        return response()->json(['message' => 'deleted']);
    }
}
