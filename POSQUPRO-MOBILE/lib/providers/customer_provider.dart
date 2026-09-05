import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../models/customer.dart';
import '../models/paginated_response.dart';

class CustomerProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Customer> _customers = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _searchQuery = '';
  String? _error;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Future<void> loadCustomers({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _customers = [];
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

      final res = await _api.get(ApiConstants.customers, queryParams: params);
      if (res['success'] == true) {
        final parsed = PaginatedResponse.fromJson(
          res['data'],
          (json) => Customer.fromJson(json),
        );
        if (refresh) {
          _customers = parsed.data;
        } else {
          _customers.addAll(parsed.data);
        }
        _hasMore = parsed.hasMorePages;
        _currentPage++;
      } else {
        _error = res['message'];
      }
    } catch (e) {
      _error = 'Gagal memuat pelanggan';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Customer?> createCustomer(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.post(ApiConstants.customers, body: data);
      if (res['success'] == true) {
        final customer = Customer.fromJson(res['data']);
        _customers.insert(0, customer);
        _isLoading = false;
        notifyListeners();
        return customer;
      }
      _error = res['message'] ?? 'Gagal membuat pelanggan';
    } catch (e) {
      _error = 'Gagal membuat pelanggan';
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  Future<Customer?> updateCustomer(int id, Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.put('${ApiConstants.customers}/$id', body: data);
      if (res['success'] == true) {
        final customer = Customer.fromJson(res['data']);
        final index = _customers.indexWhere((c) => c.id == id);
        if (index >= 0) _customers[index] = customer;
        _isLoading = false;
        notifyListeners();
        return customer;
      }
      _error = res['message'] ?? 'Gagal memperbarui pelanggan';
    } catch (e) {
      _error = 'Gagal memperbarui pelanggan';
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  Future<bool> deleteCustomer(int id) async {
    try {
      final res = await _api.delete('${ApiConstants.customers}/$id');
      if (res['success'] == true) {
        _customers.removeWhere((c) => c.id == id);
        notifyListeners();
        return true;
      }
      _error = res['message'];
    } catch (e) {
      _error = 'Gagal menghapus pelanggan';
    }
    notifyListeners();
    return false;
  }

  void search(String query) {
    _searchQuery = query;
    loadCustomers(refresh: true);
  }
}
