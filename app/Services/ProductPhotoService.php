<?php

namespace App\Services;

use App\Models\Product;
use App\Repositories\ProductRepository;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use RuntimeException;

class ProductPhotoService
{
    private const MAX_BANNER_LINES = 3;

    public function __construct(private ProductRepository $products) {}

    /**
     * Simpan foto produk baru. Foto asli (photo) tidak pernah ditimpa oleh
     * generate teks; upload selalu memperbarui photo sekaligus image.
     */
    public function upload(Product $product, UploadedFile $file): Product
    {
        $ext = strtolower($file->getClientOriginalExtension() ?: 'jpg');
        $stored = $file->storeAs(
            'products',
            $product->id.'_'.now()->timestamp.'_'.uniqid().'.'.$ext,
            'public'
        );

        $oldPaths = array_unique(array_filter([
            $this->toDiskPath($product->photo),
            $this->toDiskPath($product->image),
        ]));

        $this->products->update($product, [
            'photo' => '/storage/'.$stored,
            'image' => '/storage/'.$stored,
        ]);

        foreach ($oldPaths as $old) {
            if ($old !== 'products/'.$stored && Storage::disk('public')->exists($old)) {
                Storage::disk('public')->delete($old);
            }
        }

        return $product->fresh(['category', 'unitQuantity', 'tax', 'supplier']);
    }

    /**
     * Generate foto baru dengan banner teks nama produk di bagian bawah
     * (teks menyesuaikan panjang nama: auto-wrap + auto ukuran font).
     * Hasil disimpan sebagai file terpisah; foto asli tetap aman.
     */
    public function generateLabelPhoto(Product $product): Product
    {
        $source = $product->photo ?: $product->image;
        if (! $source) {
            throw new RuntimeException('Upload foto produk dulu sebelum generate teks.');
        }

        $image = @imagecreatefromstring($this->readPhoto($source));
        if ($image === false) {
            throw new RuntimeException('Foto produk tidak dapat dibaca.');
        }

        imagealphablending($image, true);
        imagesavealpha($image, true);

        $this->drawNameBanner($image, (string) $product->name);

        $ext = $this->outputExtension($source);
        $bytes = $this->encode($image, $ext);
        imagedestroy($image);

        $relative = 'products/labeled_'.$product->id.'_'.now()->timestamp.'.'.$ext;
        Storage::disk('public')->put($relative, $bytes);

        $oldImage = $this->toDiskPath($product->image);
        if ($oldImage && $oldImage !== $relative && $oldImage !== $this->toDiskPath($product->photo)) {
            if (Storage::disk('public')->exists($oldImage)) {
                Storage::disk('public')->delete($oldImage);
            }
        }

        $this->products->update($product, ['image' => '/storage/'.$relative]);

        return $product->fresh(['category', 'unitQuantity', 'tax', 'supplier']);
    }

    /**
     * Banner semi-transparan di bawah foto dengan nama produk putih,
     * ukuran font dan jumlah baris menyesuaikan panjang nama.
     *
     * @param  \GdImage  $image
     */
    private function drawNameBanner($image, string $name): void
    {
        $width = imagesx($image);
        $height = imagesy($image);
        $font = $this->fontPath();
        $maxTextWidth = max(1, $width - (int) round($width * 0.08));

        $minSize = max(10, (int) round($height * 0.022));
        $maxSize = max(14, (int) round($height * 0.055));

        $lines = [];
        $size = $minSize;
        for ($candidate = $maxSize; $candidate >= $minSize; $candidate--) {
            $wrapped = $this->wrapText($name, $font, $candidate, $maxTextWidth);
            if (count($wrapped) <= self::MAX_BANNER_LINES) {
                $lines = $wrapped;
                $size = $candidate;
                break;
            }
        }

        if ($lines === []) {
            $lines = array_slice($this->wrapText($name, $font, $minSize, $maxTextWidth), 0, self::MAX_BANNER_LINES);
            $size = $minSize;
        }

        $box = imagettfbbox($size, 0, $font, 'Ag');
        $lineHeight = (int) abs($box[1] - $box[7]) + (int) round($size * 0.45);
        $padding = (int) round($lineHeight * 0.45);
        $bannerHeight = min($height, $lineHeight * count($lines) + $padding * 2);
        $minBanner = max(40, (int) round($height * 0.12));
        if ($bannerHeight < $minBanner) {
            $bannerHeight = min($height, $minBanner);
        }

        $top = $height - $bannerHeight;
        $overlay = imagecolorallocatealpha($image, 0, 0, 0, 58);
        imagefilledrectangle($image, 0, $top, $width - 1, $height - 1, $overlay);

        $white = imagecolorallocate($image, 255, 255, 255);
        $ascent = (int) abs($box[7]);
        $blockHeight = $lineHeight * count($lines);
        $y = $top + (int) (($bannerHeight - $blockHeight) / 2) + $ascent;

        foreach ($lines as $line) {
            $lineWidth = (int) abs(imagettfbbox($size, 0, $font, $line)[4] - imagettfbbox($size, 0, $font, $line)[0]);
            $x = (int) (($width - $lineWidth) / 2);
            imagettftext($image, $size, 0, $x, $y, $white, $font, $line);
            $y += $lineHeight;
        }
    }

    /**
     * Pecah teks menjadi baris-baris yang muat lebar maksimum.
     *
     * @return list<string>
     */
    private function wrapText(string $text, string $font, int $size, int $maxWidth): array
    {
        $words = preg_split('/\s+/u', trim($text), -1, PREG_SPLIT_NO_EMPTY) ?: [];
        $lines = [];
        $current = '';

        foreach ($words as $word) {
            $candidate = $current === '' ? $word : $current.' '.$word;
            if ($current === '' || $this->textWidth($candidate, $font, $size) <= $maxWidth) {
                $current = $candidate;
            } else {
                $lines[] = $current;
                $current = $word;
            }
        }
        if ($current !== '') {
            $lines[] = $current;
        }

        $fitted = [];
        foreach ($lines as $line) {
            while ($this->textWidth($line, $font, $size) > $maxWidth && mb_strlen($line) > 1) {
                $keep = mb_strlen($line);
                while ($keep > 1 && $this->textWidth(mb_substr($line, 0, $keep), $font, $size) > $maxWidth) {
                    $keep--;
                }
                $fitted[] = mb_substr($line, 0, $keep);
                $line = mb_substr($line, $keep);
            }
            if ($line !== '') {
                $fitted[] = $line;
            }
        }

        return $fitted;
    }

    private function textWidth(string $text, string $font, int $size): int
    {
        $box = imagettfbbox($size, 0, $font, $text);

        return (int) abs($box[4] - $box[0]);
    }

    private function fontPath(): string
    {
        $candidates = [
            base_path('resources/fonts/Roboto-Regular.ttf'),
            'C:\\Windows\\Fonts\\arial.ttf',
            '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
            '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
        ];

        foreach ($candidates as $path) {
            if (is_file($path)) {
                return $path;
            }
        }

        throw new RuntimeException('Font untuk generate teks tidak ditemukan di server.');
    }

    private function readPhoto(string $source): string
    {
        if (preg_match('#^https?://#i', $source)) {
            $local = public_path(ltrim((string) parse_url($source, PHP_URL_PATH), '/'));
            if (is_file($local)) {
                return (string) file_get_contents($local);
            }

            $bytes = @file_get_contents($source);
            if ($bytes === false) {
                throw new RuntimeException('Foto produk tidak dapat diunduh dari server.');
            }

            return $bytes;
        }

        $diskPath = $this->toDiskPath($source);
        if ($diskPath && Storage::disk('public')->exists($diskPath)) {
            return (string) Storage::disk('public')->get($diskPath);
        }

        $local = public_path(ltrim($source, '/'));
        if (is_file($local)) {
            return (string) file_get_contents($local);
        }

        throw new RuntimeException('File foto produk tidak ditemukan.');
    }

    /**
     * Ubah nilai kolom photo/image menjadi path relatif pada disk public,
     * atau null bila bukan file lokal (mis. URL eksternal).
     */
    private function toDiskPath(?string $value): ?string
    {
        if (! $value || preg_match('#^https?://#i', $value)) {
            return null;
        }

        if (str_starts_with($value, '/storage/')) {
            return substr($value, strlen('/storage/'));
        }

        if (str_starts_with($value, '/')) {
            return null;
        }

        return $value;
    }

    private function outputExtension(string $source): string
    {
        $path = parse_url($source, PHP_URL_PATH) ?? $source;
        $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));

        return in_array($ext, ['jpg', 'jpeg', 'png', 'webp'], true) ? ($ext === 'jpeg' ? 'jpg' : $ext) : 'jpg';
    }

    /**
     * @param  \GdImage  $image
     * @return string bytes
     */
    private function encode($image, string $ext): string
    {
        ob_start();
        match ($ext) {
            'png' => imagepng($image, null, 6),
            'webp' => imagewebp($image, null, 88),
            default => imagejpeg($image, null, 88),
        };

        return (string) ob_get_clean();
    }
}
