import '../core/api_service.dart';

/// Normalisasi path foto produk menjadi URL absolut yang bisa dipakai
/// Image.network (API online, mode offline/local, atau path relatif /storage).
String? resolveProductImageUrl(dynamic value) {
  if (value == null) return null;
  final raw = value.toString().trim();
  if (raw.isEmpty || raw == 'null') return null;

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return raw;
  }

  final base = ApiService().baseUrl.replaceAll(RegExp(r'/+$'), '');
  // base biasanya https://host/api → origin https://host
  final origin = base.replaceFirst(RegExp(r'/api$'), '');

  if (raw.startsWith('/')) {
    return '$origin$raw';
  }
  return '$origin/$raw';
}

/// Ambil nilai foto pertama yang tidak kosong (photo asli lebih diprioritaskan
/// daripada image yang mungkin sudah diberi banner teks).
String? firstNonEmpty(List<dynamic> values) {
  for (final v in values) {
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return null;
}
