import 'dart:io';

class ApiConstants {
  static String baseUrl = _detectBaseUrl();
  static const String loginUrl = '/v1/login';
  static const String logoutUrl = '/v1/logout';
  static const String userUrl = '/user';

  static const String products = '/v1/products';
  static const String categories = '/v1/categories';
  static const String customers = '/v1/customers';
  static const String suppliers = '/v1/suppliers';
  static const String transactions = '/v1/transactions';
  static const String units = '/v1/unit-quantities';
  static const String taxes = '/v1/taxes';
  static const String settings = '/v1/settings';
  static const String settingsPublic = '/v1/settings/public';
  static const String financeSummary = '/v1/finance/summary';
  static const String reportsSales = '/v1/reports/sales';
  static const String reportsInventory = '/v1/reports/inventory';
  static const String registers = '/v1/registers';
  static const String registerSessions = '/v1/register-sessions';
  static const String parkedTransactions = '/v1/parked-transactions';
  static const String purchaseOrders = '/v1/purchase-orders';
  static const String stockCounts = '/v1/stock-counts';
  static const String inventoryHistories = '/v1/inventory-histories';
  static const String payments = '/v1/payments';
  static const String branches = '/v1/branches';
  static const String warehouses = '/v1/warehouses';
  static const String activityLogs = '/v1/activity-logs';
  static const String users = '/v1/users';

  static String _detectBaseUrl() {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    } else if (Platform.isIOS) {
      return 'http://127.0.0.1:8000/api';
    } else {
      return 'http://127.0.0.1:8000/api';
    }
  }
}

class AppConstants {
  static const String appName = 'POSQUPRO';
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String baseUrlKey = 'base_url';
  static String get defaultBaseUrl => ApiConstants.baseUrl;
}
