<?php

namespace Tests\Feature;

use App\Models\Invoice;
use App\Models\Plan;
use App\Models\Product;
use App\Models\Subscription;
use App\Models\Tenant;
use App\Models\User;
use App\Services\TenantOwnerService;
use Database\Seeders\RolePermissionSeeder;
use Database\Seeders\SubscriptionPlanSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SubscriptionBillingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(RolePermissionSeeder::class);
        $this->seed(SubscriptionPlanSeeder::class);
    }

    public function test_new_registration_starts_a_30_day_full_feature_demo(): void
    {
        $this->post('/daftar', [
            'name' => 'Demo Owner',
            'store_name' => 'Toko Demo',
            'email' => 'demo@posqupro.test',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'agree' => '1',
        ])->assertRedirect('/dashboard');

        $tenant = Tenant::where('name', 'Toko Demo')->firstOrFail();
        $this->assertSame('trial', $tenant->status);
        $this->assertSame('demo', $tenant->plan->slug);
        $this->assertEqualsWithDelta(30, now()->diffInDays($tenant->trial_ends_at), 0.1);

        $subscription = Subscription::where('tenant_id', $tenant->id)->latest('id')->firstOrFail();
        $this->assertSame('trialing', $subscription->status);
        $this->assertSame('demo', $subscription->plan->slug);

        $features = $tenant->plan->features;
        foreach (['pos', 'reports', 'purchase_orders', 'multi_branch', 'api_access'] as $feature) {
            $this->assertContains($feature, $features);
        }
    }

    public function test_expired_trial_blocks_api_but_allows_billing_page(): void
    {
        [$tenant, $owner] = $this->tenantWithOwner([
            'status' => 'trial',
            'trial_ends_at' => now()->subDay(),
            'plan_id' => Plan::where('slug', 'demo')->value('id'),
        ]);

        Sanctum::actingAs($owner);
        $this->getJson('/api/v1/products')
            ->assertStatus(402)
            ->assertJsonPath('code', 'subscription_inactive');

        $this->actingAs($owner)->get('/dashboard')->assertRedirect('/billing');
        $this->actingAs($owner)->get('/billing')->assertOk();

        $this->assertSame('expired', $tenant->fresh()->status);
    }

    public function test_expired_tenant_can_read_subscription_and_checkout_from_api(): void
    {
        config([
            'services.ipaymu.va' => '1179000899',
            'services.ipaymu.api_key' => 'secret-key',
            'services.ipaymu.sandbox' => true,
        ]);
        Http::fake([
            'sandbox.ipaymu.com/*' => Http::response([
                'Status' => 200,
                'Success' => true,
                'Data' => ['Url' => 'https://sandbox.ipaymu.com/pay/mobile', 'SessionID' => 'session-2'],
            ]),
        ]);

        [$tenant, $owner] = $this->tenantWithOwner([
            'status' => 'trial',
            'trial_ends_at' => now()->subDay(),
            'plan_id' => Plan::where('slug', 'demo')->value('id'),
        ]);

        Sanctum::actingAs($owner);

        $this->getJson('/api/v1/subscription')
            ->assertOk()
            ->assertJsonPath('subscription.is_expired', true);

        $this->getJson('/api/v1/billing')
            ->assertOk()
            ->assertJsonPath('status', 'expired')
            ->assertJsonCount(3, 'plans');

        $this->postJson('/api/v1/billing/checkout', [
            'plan_id' => Plan::where('slug', 'professional')->value('id'),
            'billing_cycle' => 'monthly',
        ])->assertCreated()
            ->assertJsonPath('payment_url', 'https://sandbox.ipaymu.com/pay/mobile');

        $invoice = Invoice::where('tenant_id', $tenant->id)->latest('id')->firstOrFail();
        $this->assertSame('pending', $invoice->status);
        $this->assertSame('https://sandbox.ipaymu.com/pay/mobile', $invoice->payment_url);
    }

    public function test_product_quota_is_enforced_from_the_plan(): void
    {
        $plan = Plan::create([
            'name' => 'Limited',
            'slug' => 'limited',
            'price' => 10000,
            'max_users' => 1,
            'max_products' => 1,
            'max_customers' => 1,
            'max_transactions_per_month' => 10,
            'max_branches' => 1,
            'features' => ['pos', 'products'],
            'is_active' => true,
        ]);

        [$tenant, $owner] = $this->tenantWithOwner([
            'status' => 'active',
            'plan_id' => $plan->id,
            'trial_ends_at' => now()->addMonth(),
        ]);

        Product::create([
            'tenant_id' => $tenant->id,
            'name' => 'Existing Product',
            'sku' => 'EXIST-1',
            'type' => 'finished_goods',
            'cost_price' => 1000,
            'selling_price' => 2000,
            'stock' => 5,
        ]);

        Sanctum::actingAs($owner);
        $this->postJson('/api/v1/products', [
            'name' => 'Produk Kedua',
            'type' => 'finished_goods',
            'cost_price' => 1000,
            'selling_price' => 2000,
            'stock' => 1,
        ])->assertStatus(403)
            ->assertJsonPath('message', 'Batas maksimal produk tercapai. Upgrade paket Anda untuk menambah produk.');
    }

    public function test_plan_without_feature_is_blocked_on_api(): void
    {
        [$tenant, $owner] = $this->tenantWithOwner([
            'status' => 'active',
            'plan_id' => Plan::where('slug', 'professional')->value('id'),
            'trial_ends_at' => now()->addMonth(),
        ]);

        Sanctum::actingAs($owner);
        $this->getJson('/api/v1/purchase-orders')
            ->assertStatus(403)
            ->assertJsonPath('code', 'feature_not_in_plan');
    }

    public function test_ipaymu_checkout_creates_invoice_and_redirects_to_payment(): void
    {
        config([
            'services.ipaymu.va' => '1179000899',
            'services.ipaymu.api_key' => 'secret-key',
            'services.ipaymu.sandbox' => true,
        ]);
        Http::fake([
            'sandbox.ipaymu.com/*' => Http::response([
                'Status' => 200,
                'Success' => true,
                'Data' => ['Url' => 'https://sandbox.ipaymu.com/pay/abc', 'SessionID' => 'session-1'],
            ]),
        ]);

        [$tenant, $owner] = $this->tenantWithOwner([
            'status' => 'active',
            'plan_id' => Plan::where('slug', 'professional')->value('id'),
            'trial_ends_at' => now()->addMonth(),
        ]);

        $response = $this->actingAs($owner)->post('/billing/checkout', [
            'plan_id' => Plan::where('slug', 'business')->value('id'),
            'billing_cycle' => 'monthly',
        ]);

        $response->assertRedirect('https://sandbox.ipaymu.com/pay/abc');

        $invoice = Invoice::where('tenant_id', $tenant->id)->latest('id')->firstOrFail();
        $this->assertSame('pending', $invoice->status);
        $this->assertSame('monthly', $invoice->billing_cycle);
        $this->assertSame('https://sandbox.ipaymu.com/pay/abc', $invoice->payment_url);
        $this->assertEqualsWithDelta((float) $invoice->total, (float) $invoice->subtotal * 1.11, 0.01);

        Http::assertSent(function ($request) {
            $body = $request->body();
            $hash = strtolower(hash('sha256', $body));
            $expected = hash_hmac('sha256', 'POST:1179000899:'.$hash.':secret-key', 'secret-key');

            return $request->url() === 'https://sandbox.ipaymu.com/api/v2/payment'
                && $request->hasHeader('signature', $expected);
        });
    }

    public function test_ipaymu_callback_activates_subscription_and_is_idempotent(): void
    {
        config([
            'services.ipaymu.va' => '1179000899',
            'services.ipaymu.api_key' => 'secret-key',
        ]);

        $plan = Plan::where('slug', 'business')->firstOrFail();
        [$tenant] = $this->tenantWithOwner([
            'status' => 'expired',
            'plan_id' => Plan::where('slug', 'professional')->value('id'),
        ]);

        $invoice = Invoice::create([
            'tenant_id' => $tenant->id,
            'plan_id' => $plan->id,
            'status' => 'pending',
            'billing_cycle' => 'monthly',
            'subtotal' => 349000,
            'tax_amount' => 38390,
            'total' => 387390,
            'issued_at' => now(),
            'due_at' => now()->addDays(3),
        ]);

        $payload = [
            'status' => 'berhasil',
            'status_code' => 1,
            'reference_id' => $invoice->invoice_number,
            'total' => '387390',
            'trx_id' => '12345',
        ];
        ksort($payload);
        $signature = hash_hmac('sha256', json_encode($payload), '1179000899');

        $this->withHeader('X-Signature', $signature)
            ->postJson('/api/ipaymu/callback', $payload)
            ->assertOk()
            ->assertJson(['status' => 'OK']);

        $invoice->refresh();
        $tenant->refresh();

        $this->assertSame('paid', $invoice->status);
        $this->assertSame('active', $tenant->status);
        $this->assertSame($plan->id, $tenant->plan_id);
        $this->assertSame('business', $tenant->plan->slug);
        $this->assertDatabaseHas('subscriptions', [
            'tenant_id' => $tenant->id,
            'plan_id' => $plan->id,
            'status' => 'active',
        ]);

        // Replay must not create another subscription/invoice payment.
        $count = Subscription::where('tenant_id', $tenant->id)->count();
        $this->withHeader('X-Signature', $signature)
            ->postJson('/api/ipaymu/callback', $payload)
            ->assertOk();
        $this->assertSame($count, Subscription::where('tenant_id', $tenant->id)->count());
    }

    public function test_ipaymu_callback_rejects_invalid_signature(): void
    {
        $this->postJson('/api/ipaymu/callback', ['reference_id' => 'INV-X'])
            ->assertStatus(401);
    }

    /**
     * @return array{0: Tenant, 1: User}
     */
    private function tenantWithOwner(array $attributes): array
    {
        $tenant = Tenant::create(array_merge(['name' => 'Tenant '.uniqid()], $attributes));

        [$owner] = app(TenantOwnerService::class)->create($tenant, [
            'name' => 'Tenant Owner',
            'email' => 'owner-'.uniqid().'@tenant.test',
            'password' => 'password123',
        ]);

        return [$tenant->fresh(), $owner->fresh()];
    }
}
