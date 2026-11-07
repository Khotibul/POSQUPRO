import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/constants.dart';

class ReportSales {
  final double totalRevenue;
  final int totalTransactions;
  final List<Map<String, dynamic>> daily;
  final List<Map<String, dynamic>> topProducts;

  ReportSales({
    required this.totalRevenue,
    required this.totalTransactions,
    required this.daily,
    required this.topProducts,
  });

  factory ReportSales.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> toList(dynamic v) {
      if (v is List) return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return [];
    }

    return ReportSales(
      totalRevenue: double.tryParse(json['total_revenue']?.toString() ?? '0') ?? 0,
      totalTransactions: (json['total_transactions'] as num?)?.toInt() ?? 0,
      daily: toList(json['daily']),
      topProducts: toList(json['top_products']),
    );
  }
}

class ReportInventory {
  final int totalProducts;
  final List<Map<String, dynamic>> lowStock;
  final double stockValue;
  final List<Map<String, dynamic>> movements;

  ReportInventory({
    required this.totalProducts,
    required this.lowStock,
    required this.stockValue,
    required this.movements,
  });

  factory ReportInventory.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> toList(dynamic v) {
      if (v is List) return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return [];
    }

    final stockValueMap = json['stock_value'];
    double stockValue = 0;
    if (stockValueMap is Map) {
      stockValue = double.tryParse(stockValueMap['cost_value']?.toString() ?? '0') ?? 0;
    }

    return ReportInventory(
      totalProducts: (json['total_products'] as num?)?.toInt() ?? 0,
      lowStock: toList(json['low_stock']),
      stockValue: stockValue,
      movements: toList(json['movements']),
    );
  }
}

class ReportProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  dynamic _financeSummary;
  ReportSales? _salesReport;
  ReportInventory? _inventoryReport;
  bool _isLoading = false;
  String? _error;

  dynamic get financeSummary => _financeSummary;
  ReportSales? get salesReport => _salesReport;
  ReportInventory? get inventoryReport => _inventoryReport;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadFinanceSummary() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.get(ApiConstants.financeSummary);
      if (res['success'] == true) {
        _financeSummary = res['data'];
      } else {
        _error = res['message'];
      }
    } catch (e) {
      _error = 'Gagal memuat ringkasan keuangan';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSalesReport({String? from, String? to}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final params = <String, String>{};
      if (from != null && from.isNotEmpty) params['from'] = from;
      if (to != null && to.isNotEmpty) params['to'] = to;

      final res = await _api.get(ApiConstants.reportsSales, queryParams: params);
      if (res['success'] == true) {
        final data = res['data'];
        _salesReport = ReportSales.fromJson(data is Map ? Map<String, dynamic>.from(data) : {});
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
        final data = res['data'];
        _inventoryReport = ReportInventory.fromJson(data is Map ? Map<String, dynamic>.from(data) : {});
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
