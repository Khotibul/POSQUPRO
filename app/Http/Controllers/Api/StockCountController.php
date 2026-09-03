<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\StockCountResource;
use App\Models\StockCount;
use App\Services\StockCountService;
use Illuminate\Http\Request;

class StockCountController extends Controller
{
    public function __construct(protected StockCountService $service) {}

    public function index(Request $request)
    {
        return StockCountResource::collection($this->service->paginate($request->only(['status'])));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'product_ids' => ['nullable', 'array'],
            'product_ids.*' => ['exists:products,id'],
            'is_blind' => ['boolean'],
            'notes' => ['nullable', 'string'],
        ]);

        return new StockCountResource($this->service->create($data));
    }

    public function show(StockCount $stockCount)
    {
        return new StockCountResource($stockCount->load(['user', 'approver', 'items.product']));
    }

    public function start(StockCount $stockCount)
    {
        return new StockCountResource($this->service->startCounting($stockCount));
    }

    public function record(Request $request, StockCount $stockCount)
    {
        $data = $request->validate([
            'items' => ['required', 'array'],
            'items.*.stock_count_item_id' => ['required', 'exists:stock_count_items,id'],
            'items.*.counted_quantity' => ['required', 'integer', 'min:0'],
            'items.*.notes' => ['nullable', 'string'],
        ]);

        return new StockCountResource($this->service->recordCount($stockCount, $data['items']));
    }

    public function approve(StockCount $stockCount)
    {
        return new StockCountResource($this->service->approve($stockCount));
    }

    public function post(StockCount $stockCount)
    {
        return new StockCountResource($this->service->post($stockCount));
    }
}
