import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/paginated_response.dart';

class ProductProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Product> _products = [];
  List<Category> _categories = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _searchQuery = '';
  int? _selectedCategoryId;
  String? _error;

  List<Product> get products => _filteredProducts;
  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  int? get selectedCategoryId => _selectedCategoryId;

  bool _isLoadingAll = false;

  /// Memuat seluruh katalog (bukan hanya halaman pertama) untuk kasir.
  /// Pencarian di layar kasir menjadi akurat untuk semua produk, termasuk
  /// SKU/barcode yang berada di halaman berikutnya.
  Future<void> loadAllProductsForPos() async {
    if (_isLoadingAll) return;
    _isLoadingAll = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final all = <Product>[];
      var page = 1;
      var lastPage = 1;
      do {
        final res = await _api.get(ApiConstants.products, queryParams: {
          'page': '$page',
          'per_page': '200',
        });
        if (res['success'] != true) {
          _error = res['message'] ?? 'Gagal memuat produk';
          break;
        }
        final parsed = PaginatedResponse.fromJson(
          res['data'],
          (json) => Product.fromJson(json),
        );
        all.addAll(parsed.data);
        lastPage = parsed.lastPage;
        if (parsed.data.isEmpty) break;
        page++;
      } while (page <= lastPage && page <= 200);

      if (all.isNotEmpty || _error == null) {
        _products = all;
        _currentPage = page;
        _hasMore = false;
        _applyFilter();
      }
    } catch (e) {
      _error = 'Gagal memuat produk';
    }

    _isLoadingAll = false;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadProducts({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _products = [];
    }

    if (!_hasMore || _isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final params = <String, String>{
        'page': _currentPage.toString(),
        'per_page': '20',
      };
      if (_searchQuery.isNotEmpty) params['search'] = _searchQuery;
      if (_selectedCategoryId != null) params['category_id'] = _selectedCategoryId.toString();

      final res = await _api.get(ApiConstants.products, queryParams: params);

      if (res['success'] == true) {
        final parsed = PaginatedResponse.fromJson(
          res['data'],
          (json) => Product.fromJson(json),
        );
        if (refresh) {
          _products = parsed.data;
        } else {
          _products.addAll(parsed.data);
        }
        _hasMore = parsed.hasMorePages;
        _currentPage++;
        _applyFilter();
      } else {
        _error = res['message'];
      }
    } catch (e) {
      _error = 'Gagal memuat produk';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCategories() async {
    try {
      final res = await _api.get(ApiConstants.categories, queryParams: {'per_page': '200'});
      if (res['success'] == true) {
        final items = (res['data']['data'] as List<dynamic>? ?? [])
            .map((e) => Category.fromJson(e))
            .toList();
        _categories = items;
        notifyListeners();
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _taxes = [];
  List<Map<String, dynamic>> _suppliers = [];
  bool _masterLoaded = false;

  List<Map<String, dynamic>> get units => _units;
  List<Map<String, dynamic>> get taxes => _taxes;
  List<Map<String, dynamic>> get suppliers => _suppliers;

  Future<void> loadMasterData({bool force = false}) async {
    if (_masterLoaded && !force) return;
    try {
      final results = await Future.wait([
        _api.get(ApiConstants.units),
        _api.get(ApiConstants.taxes),
        _api.get(ApiConstants.suppliers),
      ]);
      List<Map<String, dynamic>> parse(dynamic res) {
        if (res is! Map || res['success'] != true) return [];
        final data = res['data'];
        final list = data is Map ? (data['data'] ?? []) : data;
        return (list as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }

      _units = parse(results[0]);
      _taxes = parse(results[1]);
      _suppliers = parse(results[2]);
      _masterLoaded = true;
      notifyListeners();
    } catch (_) {}
  }

  void search(String query) {
    _searchQuery = query;
    _applyFilter();
    notifyListeners();
  }

  void filterByCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    _filteredProducts = _products.where((p) {
      if (!p.isActive) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!p.name.toLowerCase().contains(q) &&
            !(p.sku?.toLowerCase().contains(q) ?? false) &&
            !(p.barcode?.contains(q) ?? false)) {
          return false;
        }
      }
      if (_selectedCategoryId != null && p.categoryId != _selectedCategoryId) {
        return false;
      }
      return true;
    }).toList();
  }
}
