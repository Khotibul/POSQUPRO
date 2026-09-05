import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../models/transaction.dart';
import '../models/paginated_response.dart';

class TransactionProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Transaction> _transactions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _searchQuery = '';
  String? _error;

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Future<void> loadTransactions({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _transactions = [];
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

      final res = await _api.get(ApiConstants.transactions, queryParams: params);

      if (res['success'] == true) {
        final parsed = PaginatedResponse.fromJson(
          res['data'],
          (json) => Transaction.fromJson(json),
        );
        if (refresh) {
          _transactions = parsed.data;
        } else {
          _transactions.addAll(parsed.data);
        }
        _hasMore = parsed.hasMorePages;
        _currentPage++;
      } else {
        _error = res['message'];
      }
    } catch (e) {
      _error = 'Gagal memuat transaksi';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Transaction?> createTransaction({
    required String type,
    int? customerId,
    required List<Map<String, dynamic>> items,
    double? discount,
    double? taxAmount,
    String? notes,
    Map<String, dynamic>? payment,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'type': type,
        'items': items,
      };
      if (customerId != null) body['customer_id'] = customerId;
      if (discount != null) body['discount'] = discount;
      if (taxAmount != null) body['tax_amount'] = taxAmount;
      if (notes != null && notes.isNotEmpty) body['notes'] = notes;
      if (payment != null) body['payment'] = payment;

      final res = await _api.post(ApiConstants.transactions, body: body);

      if (res['success'] == true) {
        final transaction = Transaction.fromJson(res['data']);
        _transactions.insert(0, transaction);
        _isLoading = false;
        notifyListeners();
        return transaction;
      }

      _error = res['message'] ?? 'Gagal membuat transaksi';
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Gagal membuat transaksi';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  void search(String query) {
    _searchQuery = query;
    loadTransactions(refresh: true);
  }
}
