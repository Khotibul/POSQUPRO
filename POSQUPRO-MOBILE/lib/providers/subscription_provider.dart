import 'package:flutter/foundation.dart';
import '../core/api_service.dart';
import '../models/subscription.dart';

class SubscriptionProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  SubscriptionSnapshot? _subscription;
  BillingOverview? _billing;
  bool _isLoading = false;
  bool _isCheckingOut = false;
  bool _loaded = false;
  String? _error;

  SubscriptionSnapshot? get subscription => _subscription;
  BillingOverview? get billing => _billing;
  bool get isLoading => _isLoading;
  bool get isCheckingOut => _isCheckingOut;
  bool get isLoaded => _loaded;
  String? get error => _error;

  bool get isExpired => _subscription?.isExpired ?? false;
  bool get isBlocked =>
      _subscription != null &&
      (_subscription!.isExpired ||
          _subscription!.status == 'suspended' ||
          _subscription!.status == 'inactive');

  /// Paket lama/tanpa plan tidak dibatasi: fitur dianggap tersedia sampai
  /// server mengirim daftar fitur yang tegas.
  bool hasFeature(String feature) {
    if (!_loaded || _subscription == null || !_subscription!.hasPlan) return true;
    return _subscription!.features.contains(feature);
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    final res = await _api.get('/v1/subscription');
    _isLoading = false;

    if (res['success'] == true) {
      final data = res['data'];
      if (data is Map) {
        _subscription = SubscriptionSnapshot.fromJson(Map<String, dynamic>.from(data));
        _loaded = true;
        _error = null;
        notifyListeners();
        return;
      }
    }

    _error = res['message']?.toString() ?? 'Gagal memuat status langganan';
    notifyListeners();
  }

  Future<BillingOverview?> loadBilling() async {
    _isLoading = true;
    notifyListeners();

    final res = await _api.get('/v1/billing');
    _isLoading = false;

    if (res['success'] == true && res['data'] is Map) {
      final overview = BillingOverview.fromJson(Map<String, dynamic>.from(res['data'] as Map));
      _billing = overview;
      _subscription = overview.subscription;
      _loaded = true;
      _error = null;
      notifyListeners();
      return overview;
    }

    _error = res['message']?.toString() ?? 'Gagal memuat paket langganan';
    notifyListeners();
    return null;
  }

  /// Membuat invoice + tautan iPaymu. Mengembalikan URL pembayaran.
  Future<String?> checkout(int planId, String billingCycle) async {
    _isCheckingOut = true;
    _error = null;
    notifyListeners();

    final res = await _api.post('/v1/billing/checkout', body: {
      'plan_id': planId,
      'billing_cycle': billingCycle,
    });

    _isCheckingOut = false;

    if (res['success'] == true && res['data'] is Map) {
      final data = Map<String, dynamic>.from(res['data'] as Map);
      final url = data['payment_url']?.toString();
      notifyListeners();
      return url;
    }

    _error = res['message']?.toString() ?? 'Gagal membuat pembayaran';
    notifyListeners();
    return null;
  }

  void clear() {
    _subscription = null;
    _billing = null;
    _loaded = false;
    _error = null;
    notifyListeners();
  }
}
