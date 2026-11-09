<?php

namespace Tests\Feature;

use App\Models\Product;
use App\Models\User;
use Database\Seeders\PosquproSeeder;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

class ProductPhotoTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(RolePermissionSeeder::class);
        $this->seed(PosquproSeeder::class);
        Storage::fake('public');
    }

    public function test_upload_photo_and_generate_label_keeps_original(): void
    {
        $user = User::role('Admin')->first();
        $product = Product::first();

        $response = $this->actingAs($user)->postJson("/api/v1/products/{$product->id}/photo", [
            'photo' => UploadedFile::fake()->image('produk.jpg', 640, 480),
        ]);

        $response->assertOk();
        $photo = $response->json('data.photo');
        $this->assertNotEmpty($photo);
        $this->assertStringStartsWith('http', $photo);
        $this->assertStringContainsString('/storage/products/', $photo);
        Storage::disk('public')->assertExists(Str::after($photo, '/storage/'));

        $generate = $this->actingAs($user)->postJson("/api/v1/products/{$product->id}/generate-label");
        $generate->assertOk();

        $labeled = $generate->json('data.image');
        $this->assertStringContainsString('labeled_', $labeled);
        $this->assertSame($photo, $generate->json('data.photo'), 'Foto asli harus tetap aman setelah generate');
        Storage::disk('public')->assertExists(Str::after($labeled, '/storage/'));

        $product->refresh();
        $this->assertStringStartsWith('/storage/products/', $product->photo);
        $this->assertStringContainsString('labeled_', $product->image);
        $this->assertSame(basename((string) $photo), basename((string) $product->photo));
        $this->assertSame(basename((string) $labeled), basename((string) $product->image));
    }

    public function test_generate_without_photo_returns_422(): void
    {
        $user = User::role('Admin')->first();
        $product = Product::first();
        $product->update(['photo' => null, 'image' => null]);

        $this->actingAs($user)
            ->postJson("/api/v1/products/{$product->id}/generate-label")
            ->assertStatus(422)
            ->assertJson(['message' => 'Upload foto produk dulu sebelum generate teks.']);
    }

    public function test_upload_rejects_non_image_file(): void
    {
        $user = User::role('Admin')->first();
        $product = Product::first();

        $this->actingAs($user)->postJson("/api/v1/products/{$product->id}/photo", [
            'photo' => UploadedFile::fake()->create('dokumen.pdf', 100, 'application/pdf'),
        ])->assertStatus(422);
    }
}
