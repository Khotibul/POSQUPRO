import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    if (token == null || token.isEmpty) return false;

    _api.setToken(token);
    try {
      final res = await _api.get(ApiConstants.userUrl);
      if (res['success'] == true) {
        final userData = res['data'];
        _user = User.fromJson(userData);
        notifyListeners();
        return true;
      }
    } catch (_) {}

    await prefs.remove(AppConstants.tokenKey);
    _api.setToken(null);
    return false;
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.post(ApiConstants.loginUrl, body: {
        'email': email,
        'password': password,
      });

      if (res['success'] == true) {
        final data = res['data'];
        final token = data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, token);
        _api.setToken(token);
        _user = User.fromJson(data['user']);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = res['message'] ?? 'Login gagal';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Tidak dapat terhubung ke server';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.post(ApiConstants.logoutUrl);
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    _api.setToken(null);
    _user = null;
    notifyListeners();
  }
}
