<?php

namespace Tests\Feature;

use App\Models\Tenant;
use App\Models\User;
use App\Services\TenantOwnerService;
use Database\Seeders\PosquproSeeder;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RegisterTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(RolePermissionSeeder::class);
        $this->seed(PosquproSeeder::class);
    }

    public function test_web_daftar_page_renders(): void
    {
        $this->get('/daftar')->assertOk();
    }

    public function test_web_daftar_requires_fields(): void
    {
        $this->post('/daftar', [])
            ->assertSessionHasErrors(['name', 'store_name', 'email', 'password', 'agree']);
    }

    public function test_web_daftar_rejects_short_password(): void
    {
        $this->post('/daftar', [
            'name' => 'Owner Baru',
            'store_name' => 'Toko Baru',
            'email' => 'baru@toko.test',
            'password' => 'short',
            'password_confirmation' => 'short',
            'agree' => '1',
        ])->assertSessionHasErrors(['password']);
    }

    public function test_web_daftar_creates_tenant_owner_and_logs_in(): void
    {
        $this->post('/daftar', [
            'name' => 'Owner Baru',
            'store_name' => 'Toko Baru',
            'email' => 'baru@toko.test',
            'phone' => '081234567890',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'agree' => '1',
        ])->assertRedirect('/dashboard');

        $this->assertAuthenticated();

        $tenant = Tenant::where('name', 'Toko Baru')->firstOrFail();
        $this->assertSame('trial', $tenant->status);
        $this->assertNotNull($tenant->owner_id);

        $owner = User::where('email', 'baru@toko.test')->firstOrFail();
        $this->assertSame($tenant->id, $owner->tenant_id);
        $this->assertSame('ADMIN', $owner->role);
    }

    public function test_web_daftar_rejects_duplicate_email(): void
    {
        $tenant = Tenant::create(['name' => 'Existing Co', 'status' => 'trial']);
        app(TenantOwnerService::class)->create($tenant, [
            'name' => 'Existing Owner',
            'email' => 'existing@toko.test',
            'password' => 'password123',
        ]);

        $this->post('/daftar', [
            'name' => 'Dup',
            'store_name' => 'Dup Co',
            'email' => 'existing@toko.test',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'agree' => '1',
        ])->assertSessionHasErrors(['email']);

        $this->assertGuest();
    }

    public function test_api_register_requires_fields(): void
    {
        $this->postJson('/api/v1/register', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['name', 'tenant_name', 'email', 'password']);
    }

    public function test_api_register_creates_token_and_user(): void
    {
        $response = $this->postJson('/api/v1/register', [
            'name' => 'Mobile Owner',
            'tenant_name' => 'Mobile Toko',
            'email' => 'mobile@toko.test',
            'phone' => '08111111111',
            'password' => 'password123',
        ]);

        $response->assertStatus(201)
            ->assertJsonStructure(['token', 'user' => ['id', 'name', 'email', 'role', 'tenant_id'], 'tenant' => ['id', 'name', 'status']]);

        $tenant = Tenant::where('name', 'Mobile Toko')->firstOrFail();
        $this->assertSame('trial', $tenant->status);
        $this->assertNotNull($tenant->trial_ends_at);

        $owner = User::where('email', 'mobile@toko.test')->firstOrFail();
        $this->assertSame($tenant->id, $owner->tenant_id);

        $token = $response->json('token');
        $this->assertIsString($token);

        $this->withToken($token)->getJson('/api/user')->assertOk();
    }

    public function test_api_register_rejects_duplicate_email(): void
    {
        $tenant = Tenant::create(['name' => 'Dup Api Co', 'status' => 'trial']);
        app(TenantOwnerService::class)->create($tenant, [
            'name' => 'Dup Api',
            'email' => 'dup@api.test',
            'password' => 'password123',
        ]);

        $this->postJson('/api/v1/register', [
            'name' => 'Dup',
            'tenant_name' => 'Dup Api Co 2',
            'email' => 'dup@api.test',
            'password' => 'password123',
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['email']);
    }
}
