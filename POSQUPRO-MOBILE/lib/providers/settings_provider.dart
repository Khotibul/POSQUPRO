import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../models/setting.dart';

class SettingsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Setting> _settings = [];
  Map<String, String> _publicSettings = {};
  bool _isLoading = false;
  String? _error;

  List<Setting> get settings => _settings;
  Map<String, String> get publicSettings => _publicSettings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String getSetting(String key, {String defaultValue = ''}) {
    return _publicSettings[key] ?? defaultValue;
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.get(ApiConstants.settings);
      if (res['success'] == true) {
        final items = res['data']['data'];
        if (items is List) {
          _settings = items.map((e) => Setting.fromJson(e)).toList();
        }
      } else {
        _error = res['message'];
      }
    } catch (e) {
      _error = 'Gagal memuat pengaturan';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadPublicSettings() async {
    try {
      final res = await _api.get(ApiConstants.settingsPublic);
      if (res['success'] == true) {
        final data = res['data'];
        if (data is Map) {
          _publicSettings = data.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> updateSetting(String key, String value) async {
    try {
      final res = await _api.post(ApiConstants.settings, body: {
        'setting_key': key,
        'setting_value': value,
      });
      if (res['success'] == true) {
        _publicSettings[key] = value;
        notifyListeners();
        return true;
      }
      _error = res['message'];
    } catch (e) {
      _error = 'Gagal memperbarui pengaturan';
    }
    notifyListeners();
    return false;
  }

  Future<bool> updateSettingsGroup(String group, Map<String, String> data) async {
    try {
      // Website stores keys like store_name; API accepts key/value pairs via group payload
      final res = await _api.post(ApiConstants.settings, body: {
        'group': group,
        'settings': data,
      });
      if (res['success'] == true) {
        data.forEach((k, v) => _publicSettings[k] = v);
        // also map store_name style keys used by website
        if (group == 'store') {
          final map = {'store.name': 'store_name', 'store.phone': 'store_phone', 'store.address': 'store_address', 'receipt.footer': 'receipt_footer'};
          for (final e in map.entries) {
            if (data.containsKey(e.key)) _publicSettings[e.value] = data[e.key]!;
          }
        }
        notifyListeners();
        return true;
      }
      _error = res['message'];
    } catch (e) {
      _error = 'Gagal memperbarui pengaturan';
    }
    notifyListeners();
    return false;
  }

  Future<bool> saveSettingPair(String key, String value) async {
    try {
      final res = await _api.post(ApiConstants.settings, body: {
        'key': key,
        'value': value,
        'group': key.split('.').first,
      });
      if (res['success'] == true) {
        _publicSettings[key] = value;
        notifyListeners();
        return true;
      }
      _error = res['message'];
    } catch (e) {
      _error = 'Gagal memperbarui pengaturan';
    }
    notifyListeners();
    return false;
  }
}
