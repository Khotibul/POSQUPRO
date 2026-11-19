class PaginatedResponse<T> {
  final List<T> data;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final bool hasMorePages;

  PaginatedResponse({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.hasMorePages,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final dataList = (json['data'] as List<dynamic>? ?? [])
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();

    // Resource Laravel (ProductResource/TransactionResource) menaruh kunci
    // pager di dalam `meta`, sedangkan paginator mentah (kategori/customer)
    // menaruhnya di top-level. Dukung keduanya.
    final meta = json['meta'] is Map ? Map<String, dynamic>.from(json['meta']) : const <String, dynamic>{};
    int readInt(String key, int fallback) {
      final v = json[key] ?? meta[key];
      if (v == null) return fallback;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? fallback;
    }

    final currentPage = readInt('current_page', 1);
    final lastPage = readInt('last_page', 1);

    return PaginatedResponse(
      data: dataList,
      currentPage: currentPage,
      lastPage: lastPage,
      perPage: readInt('per_page', 15),
      total: readInt('total', dataList.length),
      hasMorePages: currentPage < lastPage,
    );
  }
}
