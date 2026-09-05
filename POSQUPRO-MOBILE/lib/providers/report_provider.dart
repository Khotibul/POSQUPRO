import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../models/setting.dart';

class ReportProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  FinanceSummary? _financeSummary;
  List<Map<String, dynamic>> _salesReport = [];
  List<Map<String, dynamic>> _inventoryReport = [];
  bool _isLoading = false;
  String? _error;

  FinanceSummary? get financeSummary => _financeSummary;
  List<Map<String, dynamic>> get salesReport => _salesReport;
  List<Map<String, dynamic>> get inventoryReport => _inventoryReport;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadFinanceSummary() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.get(ApiConstants.financeSummary);
      if (res['success'] == true) {
        _financeSummary = FinanceSummary.fromJson(res['data']);
      } else {
        _error = res['message'];
      }
    } catch (e) {
      _error = 'Gagal memuat ringkasan keuangan';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSalesReport({String? startDate, String? endDate}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final params = <String, String>{};
      if (startDate != null) params['start_date'] = startDate;
      if (endDate != null) params['end_date'] = endDate;

      final res = await _api.get(ApiConstants.reportsSales, queryParams: params);
      if (res['success'] == true) {
        _salesReport = List<Map<String, dynamic>>.from(res['data']?['data'] ?? []);
      } else {
        _error = res['message'];
      }
    } catch (e) {
      _error = 'Gagal memuat laporan penjualan';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadInventoryReport() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.get(ApiConstants.reportsInventory);
      if (res['success'] == true) {
        _inventoryReport = List<Map<String, dynamic>>.from(res['data']?['data'] ?? []);
      } else {
        _error = res['message'];
      }
    } catch (e) {
      _error = 'Gagal memuat laporan inventaris';
    }

    _isLoading = false;
    notifyListeners();
  }
}
