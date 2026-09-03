<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RegisterSessionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'register' => new RegisterResource($this->whenLoaded('register')),
            'user' => $this->whenLoaded('user'),
            'opener' => $this->whenLoaded('opener'),
            'closer' => $this->whenLoaded('closer'),
            'opening_float' => $this->opening_float,
            'expected_cash' => $this->expected_cash,
            'actual_cash' => $this->actual_cash,
            'over_short' => $this->over_short,
            'status' => $this->status,
            'opened_at' => $this->opened_at,
            'closed_at' => $this->closed_at,
            'notes' => $this->notes,
            'close_notes' => $this->close_notes,
            'created_at' => $this->created_at,
        ];
    }
}
