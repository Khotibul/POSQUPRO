<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Invoice;
use App\Services\IpaymuService;
use App\Services\SubscriptionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class IpaymuController extends Controller
{
    public function callback(Request $request, IpaymuService $ipaymu): JsonResponse
    {
        $payload = $request->isJson() ? (array) $request->json()->all() : $request->all();

        if (! $ipaymu->verifyCallbackSignature($payload, $request->header('X-Signature'))) {
            return response()->json(['status' => 'Invalid Signature'], 401);
        }

        $reference = $payload['reference_id'] ?? null;
        $invoice = $reference
            ? Invoice::with(['tenant', 'plan'])->where('invoice_number', $reference)->first()
            : null;

        if (! $invoice) {
            Log::warning('iPaymu callback for unknown invoice', ['reference' => $reference]);

            return response()->json(['status' => 'OK']);
        }

        if ($invoice->isPaid()) {
            return response()->json(['status' => 'OK']); // idempotent replay
        }

        if ($ipaymu->isExpiredPayload($payload)) {
            $invoice->update(['status' => 'cancelled', 'notes' => 'Kedaluwarsa di iPaymu']);

            return response()->json(['status' => 'OK']);
        }

        if (! $ipaymu->isSuccessPayload($payload)) {
            return response()->json(['status' => 'OK']);
        }

        $amount = (float) ($payload['total'] ?? $payload['amount'] ?? 0);
        if ($amount + 0.5 < (float) $invoice->total) {
            Log::error('iPaymu callback amount mismatch', [
                'invoice' => $invoice->id,
                'expected' => $invoice->total,
                'received' => $amount,
            ]);

            return response()->json(['status' => 'Amount Mismatch'], 400);
        }

        app(SubscriptionService::class)->markInvoicePaid(
            $invoice,
            isset($payload['trx_id']) ? (string) $payload['trx_id'] : null,
            [
                'ipaymu_via' => $payload['via'] ?? null,
                'ipaymu_channel' => $payload['channel'] ?? null,
                'ipaymu_paid_at' => $payload['paid_at'] ?? null,
            ],
        );

        return response()->json(['status' => 'OK']);
    }
}
