import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../models/register.dart';

class RegisterProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Register> _registers = [];
  RegisterSession? _currentSession;
  bool _isLoading = false;
  String? _error;

  List<Register> get registers => _registers;
  RegisterSession? get currentSession => _currentSession;
  bool get isLoading => _isLoading;
  bool get hasOpenSession => _currentSession?.status == 'open';
  String? get error => _error;

  Future<void> loadRegisters() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.get(ApiConstants.registers);
      if (res['success'] == true) {
        final items = res['data']['data'];
        if (items is List) {
          _registers = items.map((e) => Register.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCurrentSession(int registerId) async {
    try {
      final res = await _api.get('${ApiConstants.registerSessions}/current/$registerId');
      if (res['success'] == true && res['data'] != null) {
        _currentSession = RegisterSession.fromJson(res['data']);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> openSession(int registerId, double openingBalance) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.post('${ApiConstants.registerSessions}/open', body: {
        'register_id': registerId,
        'opening_balance': openingBalance,
      });
      if (res['success'] == true) {
        _currentSession = RegisterSession.fromJson(res['data']);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = res['message'] ?? 'Gagal membuka sesi kasir';
    } catch (e) {
      _error = 'Gagal membuka sesi kasir';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> closeSession(double closingBalance) async {
    if (_currentSession == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.post(
        '${ApiConstants.registerSessions}/${_currentSession!.id}/close',
        body: {'closing_balance': closingBalance},
      );
      if (res['success'] == true) {
        _currentSession = null;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = res['message'] ?? 'Gagal menutup sesi kasir';
    } catch (e) {
      _error = 'Gagal menutup sesi kasir';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }
}
