import 'package:flutter/material.dart';
import '../core/product_image_url.dart';
import '../core/theme.dart';

/// Thumbnail foto produk yang menampilkan gambar asli produk
/// (prioritas photo, fallback image) dengan placeholder bila tidak ada.
class ProductImage extends StatelessWidget {
  final String? photo;
  final String? image;
  final double size;
  final double radius;
  final IconData placeholderIcon;

  const ProductImage({
    super.key,
    required this.photo,
    this.image,
    this.size = 56,
    this.radius = 10,
    this.placeholderIcon = Icons.inventory_2_rounded,
  });

  /// Ambil dari model Product (field image sudah diisi photo/image).
  factory ProductImage.fromProduct({
    Key? key,
    required String? imageUrl,
    double size = 56,
    double radius = 10,
  }) {
    return ProductImage(
      key: key,
      photo: imageUrl,
      size: size,
      radius: radius,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Prioritas foto asli; image (banner teks) hanya fallback.
    final url = resolveProductImageUrl(firstNonEmpty([photo, image]));

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? _placeholder()
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: size,
              height: size,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              errorBuilder: (_, __, ___) => _placeholder(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: size,
                  height: size,
                  color: AppColors.primarySurface,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: size * 0.35,
                    height: size * 0.35,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      color: AppColors.primarySurface,
      alignment: Alignment.center,
      child: Icon(placeholderIcon, color: AppColors.primary, size: size * 0.42),
    );
  }
}
