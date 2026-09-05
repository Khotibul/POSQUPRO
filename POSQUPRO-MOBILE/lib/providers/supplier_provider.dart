import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../models/supplier.dart';
import '../models/paginated_response.dart';

class SupplierProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Supplier> _suppliers = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _searchQuery = '';
  String? _error;

  List<Supplier> get suppliers => _suppliers;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Future<void> loadSuppliers({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _suppliers = [];
    }
    if (!_hasMore || _isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final params = <String, String>{
        'page': _currentPage.toString(),
        'per_page': '50',
      };
      if (_searchQuery.isNotEmpty) params['search'] = _searchQuery;

      final res = await _api.get(ApiConstants.suppliers, queryParams: params);
      if (res['success'] == true) {
        final parsed = PaginatedResponse.fromJson(
          res['data'],
          (json) => Supplier.fromJson(json),
        );
        if (refresh) {
          _suppliers = parsed.data;
        } else {
          _suppliers.addAll(parsed.data);
        }
        _hasMore = parsed.hasMorePages;
        _currentPage++;
      } else {
        _error = res['message'];
      }
    } catch (e) {
      _error = 'Gagal memuat supplier';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Supplier?> createSupplier(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.post(ApiConstants.suppliers, body: data);
      if (res['success'] == true) {
        final supplier = Supplier.fromJson(res['data']);
        _suppliers.insert(0, supplier);
        _isLoading = false;
        notifyListeners();
        return supplier;
      }
      _error = res['message'] ?? 'Gagal membuat supplier';
    } catch (e) {
      _error = 'Gagal membuat supplier';
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  Future<Supplier?> updateSupplier(int id, Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.put('${ApiConstants.suppliers}/$id', body: data);
      if (res['success'] == true) {
        final supplier = Supplier.fromJson(res['data']);
        final index = _suppliers.indexWhere((s) => s.id == id);
        if (index >= 0) _suppliers[index] = supplier;
        _isLoading = false;
        notifyListeners();
        return supplier;
      }
      _error = res['message'] ?? 'Gagal memperbarui supplier';
    } catch (e) {
      _error = 'Gagal memperbarui supplier';
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  Future<bool> deleteSupplier(int id) async {
    try {
      final res = await _api.delete('${ApiConstants.suppliers}/$id');
      if (res['success'] == true) {
        _suppliers.removeWhere((s) => s.id == id);
        notifyListeners();
        return true;
      }
      _error = res['message'];
    } catch (e) {
      _error = 'Gagal menghapus supplier';
    }
    notifyListeners();
    return false;
  }

  void search(String query) {
    _searchQuery = query;
    loadSuppliers(refresh: true);
  }
}
