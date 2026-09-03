<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class StockCountResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'count_number' => $this->count_number,
            'user' => $this->whenLoaded('user'),
            'approver' => $this->whenLoaded('approver'),
            'items' => StockCountItemResource::collection($this->whenLoaded('items')),
            'status' => $this->status,
            'is_blind' => $this->is_blind,
            'counted_at' => $this->counted_at,
            'approved_at' => $this->approved_at,
            'posted_at' => $this->posted_at,
            'notes' => $this->notes,
            'created_at' => $this->created_at,
        ];
    }
}
