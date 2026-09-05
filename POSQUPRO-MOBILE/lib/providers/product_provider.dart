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
      final res = await _api.get(ApiConstants.categories);
      if (res['success'] == true) {
        final items = (res['data']['data'] as List<dynamic>? ?? [])
            .map((e) => Category.fromJson(e))
            .toList();
        _categories = items;
        notifyListeners();
      }
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
