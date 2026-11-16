<?php

namespace Tests\Feature;

use App\Models\Tenant;
use App\Models\User;
use App\Services\TenantOwnerService;
use Database\Seeders\PosquproSeeder;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class TenantOwnerTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(RolePermissionSeeder::class);
        $this->seed(PosquproSeeder::class);
    }

    private function superAdmin(): User
    {
        return User::role('Super Admin')->firstOrFail();
    }

    private function makeTenantWithOwner(): Tenant
    {
        $tenant = Tenant::create(['name' => 'Owner Sync Co', 'status' => 'trial']);
        app(TenantOwnerService::class)->create($tenant, [
            'name' => 'Owner Lama',
            'email' => 'owner.lama@tenant.test',
            'password' => 'password123',
        ]);

        return $tenant->fresh();
    }

    public function test_web_store_requires_owner_fields(): void
    {
        $this->actingAs($this->superAdmin())
            ->post('/tenants', ['name' => 'No Owner Co'])
            ->assertSessionHasErrors(['owner_name', 'owner_email']);
    }

    public function test_api_store_requires_owner_fields(): void
    {
        $this->actingAs($this->superAdmin());

        $this->postJson('/api/v1/tenants', ['name' => 'No Owner Co'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['owner_name', 'owner_email']);
    }

    public function test_api_store_creates_owner_user_in_tenant(): void
    {
        $this->actingAs($this->superAdmin());

        $this->postJson('/api/v1/tenants', [
            'name' => 'API Tenant Co',
            'owner_name' => 'Budi',
            'owner_email' => 'budi@apitenant.test',
            'owner_password' => 'password123',
        ])->assertStatus(201);

        $tenant = Tenant::where('name', 'API Tenant Co')->firstOrFail();
        $this->assertNotNull($tenant->owner_id);

        $owner = User::where('email', 'budi@apitenant.test')->firstOrFail();
        $this->assertSame($tenant->id, $owner->tenant_id);
        $this->assertSame('ADMIN', $owner->role);
        $this->assertTrue(Hash::check('password123', $owner->password));
    }

    public function test_api_update_syncs_owner_user(): void
    {
        $this->actingAs($this->superAdmin());
        $tenant = $this->makeTenantWithOwner();

        $this->putJson("/api/v1/tenants/{$tenant->id}", [
            'name' => 'Owner Sync Co Updated',
            'status' => 'active',
            'owner_name' => 'Owner Baru',
            'owner_email' => 'owner.baru@tenant.test',
            'owner_password' => 'newpassword123',
        ])->assertOk()
            ->assertJsonPath('owner.email', 'owner.baru@tenant.test');

        $this->assertDatabaseHas('tenants', [
            'id' => $tenant->id,
            'name' => 'Owner Sync Co Updated',
            'status' => 'active',
        ]);

        $owner = $tenant->fresh()->owner;
        $this->assertSame('Owner Baru', $owner->name);
        $this->assertSame('owner.baru@tenant.test', $owner->email);
        $this->assertTrue(Hash::check('newpassword123', $owner->password));
    }

    public function test_web_update_syncs_owner_user(): void
    {
        $tenant = $this->makeTenantWithOwner();

        $this->actingAs($this->superAdmin())
            ->put("/tenants/{$tenant->id}", [
                'name' => 'Owner Sync Co',
                'status' => 'trial',
                'owner_name' => 'Owner Web',
                'owner_email' => 'owner.web@tenant.test',
            ])
            ->assertRedirect()
            ->assertSessionHas('success');

        $owner = $tenant->fresh()->owner;
        $this->assertSame('Owner Web', $owner->name);
        $this->assertSame('owner.web@tenant.test', $owner->email);
        // Password untouched when not provided
        $this->assertTrue(Hash::check('password123', $owner->password));
    }

    public function test_update_without_owner_fields_keeps_user(): void
    {
        $this->actingAs($this->superAdmin());
        $tenant = $this->makeTenantWithOwner();

        $this->putJson("/api/v1/tenants/{$tenant->id}", [
            'name' => 'Renamed Co',
            'status' => 'trial',
        ])->assertOk();

        $owner = $tenant->fresh()->owner;
        $this->assertSame('Owner Lama', $owner->name);
        $this->assertSame('owner.lama@tenant.test', $owner->email);
    }

    public function test_update_owner_email_must_be_unique(): void
    {
        $this->actingAs($this->superAdmin());
        $tenant = $this->makeTenantWithOwner();
        User::where('email', 'superadmin@posqupro.test')->firstOrFail();

        $this->putJson("/api/v1/tenants/{$tenant->id}", [
            'name' => 'Owner Sync Co',
            'status' => 'trial',
            'owner_email' => 'superadmin@posqupro.test',
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['owner_email']);
    }

    public function test_update_creates_owner_when_tenant_has_none(): void
    {
        $this->actingAs($this->superAdmin());
        $tenant = Tenant::create(['name' => 'No Owner Yet Co', 'status' => 'trial']);
        $this->assertNull($tenant->owner_id);

        $this->putJson("/api/v1/tenants/{$tenant->id}", [
            'name' => 'No Owner Yet Co',
            'status' => 'trial',
            'owner_name' => 'Owner Pertama',
            'owner_email' => 'pertama@tenant.test',
            'owner_password' => 'password123',
        ])->assertOk();

        $tenant->refresh();
        $this->assertNotNull($tenant->owner_id);
        $owner = $tenant->owner;
        $this->assertSame('Owner Pertama', $owner->name);
        $this->assertSame($tenant->id, $owner->tenant_id);
        $this->assertTrue(Hash::check('password123', $owner->password));
    }
}
