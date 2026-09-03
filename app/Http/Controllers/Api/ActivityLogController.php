<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ActivityLogResource;
use App\Models\ActivityLog;
use Illuminate\Http\Request;

class ActivityLogController extends Controller
{
    public function index(Request $request)
    {
        return ActivityLogResource::collection(ActivityLog::with(['subject', 'user'])
            ->when($request->event, fn ($q, $v) => $q->where('event', $v))
            ->when($request->subject_type, fn ($q, $v) => $q->where('subject_type', $v))
            ->when($request->user_id, fn ($q, $v) => $q->where('user_id', $v))
            ->latest()->paginate(20));
    }
}
