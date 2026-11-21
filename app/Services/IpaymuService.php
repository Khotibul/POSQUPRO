<?php

namespace App\Services;

use App\Models\Invoice;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * Minimal iPaymu API v2 client for subscription payments.
 *
 * Docs: https://docs.ipaymu.com (Redirect Payment, Signature, Callback).
 */
class IpaymuService
{
    public function isConfigured(): bool
    {
        return filled(config('services.ipaymu.va')) && filled(config('services.ipaymu.api_key'));
    }

    /**
     * Create a hosted iPaymu payment page and return its URL.
     *
     * @return array{url: string, reference: string, raw: array}
     */
    public function createRedirectPayment(Invoice $invoice): array
    {
        if (! $this->isConfigured()) {
            throw new RuntimeException('Payment gateway iPaymu belum dikonfigurasi. Hubungi administrator.');
        }

        $tenant = $invoice->tenant;
        $plan = $invoice->plan;
        $amount = max(1, (int) round((float) $invoice->total));

        $body = [
            'product' => ["Langganan POSQUPRO {$plan?->name} ({$invoice->billing_cycle})"],
            'qty' => ['1'],
            'price' => [(string) $amount],
            'amount' => (string) $amount,
            'returnUrl' => route('billing.return', $invoice),
            'cancelUrl' => route('billing.index'),
            'notifyUrl' => url('/api/ipaymu/callback'),
            'referenceId' => $invoice->invoice_number,
            'buyerName' => $tenant?->owner?->name ?? $tenant?->name ?? 'POSQUPRO',
            'buyerEmail' => $tenant?->email ?? $tenant?->owner?->email ?? '',
            'buyerPhone' => $tenant?->phone ?? '',
        ];

        $response = $this->post('/payment', $body);

        $url = $response['Data']['Url']
            ?? $response['Data']['URL']
            ?? $response['Url']
            ?? $response['Data']['PaymentUrl']
            ?? null;

        if (! $url) {
            Log::error('iPaymu redirect payment failed', ['response' => $response, 'invoice' => $invoice->id]);
            throw new RuntimeException($response['Message'] ?? 'Gagal membuat pembayaran iPaymu.');
        }

        return [
            'url' => $url,
            'reference' => (string) ($response['Data']['SessionID'] ?? $response['Data']['TransactionId'] ?? $invoice->invoice_number),
            'raw' => $response,
        ];
    }

    /**
     * Server-to-server status check (authoritative confirmation).
     */
    public function checkTransaction(string|int $transactionId): ?array
    {
        if (! $this->isConfigured()) {
            return null;
        }

        try {
            $response = $this->post('/transaction', ['transactionId' => (string) $transactionId]);
        } catch (RuntimeException $e) {
            Log::warning('iPaymu check transaction failed', ['trx_id' => $transactionId, 'error' => $e->getMessage()]);

            return null;
        }

        return $response['Data'] ?? null;
    }

    /**
     * Callback signature = HMAC-SHA256(json(ksort(payload)), VA).
     */
    public function verifyCallbackSignature(array $payload, ?string $signature): bool
    {
        $va = (string) config('services.ipaymu.va');
        if ($va === '' || blank($signature)) {
            return false;
        }

        unset($payload['signature']);
        ksort($payload);

        $expected = hash_hmac('sha256', json_encode($payload), $va);

        return hash_equals($expected, (string) $signature);
    }

    public function isSuccessPayload(array $payload): bool
    {
        $status = strtolower((string) ($payload['status'] ?? ''));

        return in_array($status, ['berhasil', 'success', 'paid'], true)
            || (int) ($payload['status_code'] ?? 0) === 1
            || (int) ($payload['transaction_status_code'] ?? 0) === 1;
    }

    public function isExpiredPayload(array $payload): bool
    {
        $status = strtolower((string) ($payload['status'] ?? ''));

        return $status === 'expired' || (int) ($payload['status_code'] ?? 0) === -2;
    }

    /**
     * @return array<string, mixed>
     */
    protected function post(string $path, array $body): array
    {
        $va = (string) config('services.ipaymu.va');
        $apiKey = (string) config('services.ipaymu.api_key');
        $jsonBody = json_encode($body, JSON_UNESCAPED_SLASHES);
        $hash = strtolower(hash('sha256', $jsonBody));
        $stringToSign = 'POST:'.$va.':'.$hash.':'.$apiKey;
        $signature = hash_hmac('sha256', $stringToSign, $apiKey);

        $response = Http::withHeaders([
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'va' => $va,
            'signature' => $signature,
            'timestamp' => now()->format('YmdHis'),
        ])->withBody($jsonBody, 'application/json')->post($this->baseUrl().$path);

        if (! $response->successful()) {
            Log::error('iPaymu HTTP error', ['path' => $path, 'status' => $response->status(), 'body' => $response->body()]);
            throw new RuntimeException('iPaymu menolak permintaan (HTTP '.$response->status().').');
        }

        $json = $response->json();
        if (! is_array($json)) {
            throw new RuntimeException('Respons iPaymu tidak valid.');
        }

        if ((int) ($json['Status'] ?? 200) >= 400 || ($json['Success'] ?? true) === false) {
            throw new RuntimeException($json['Message'] ?? 'Transaksi iPaymu gagal.');
        }

        return $json;
    }

    protected function baseUrl(): string
    {
        $configured = config('services.ipaymu.base_url');

        if (filled($configured)) {
            return rtrim($configured, '/');
        }

        return config('services.ipaymu.sandbox') ? 'https://sandbox.ipaymu.com/api/v2' : 'https://my.ipaymu.com/api/v2';
    }
}
