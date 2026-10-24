import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/db_config.dart';

class DatabaseConfigService {
  static final DatabaseConfigService _instance = DatabaseConfigService._internal();
  factory DatabaseConfigService() => _instance;
  DatabaseConfigService._internal();

  static const String _key = 'db_config_v1';
  static const String _configuredKey = 'db_configured_v1';

  Future<bool> isConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_configuredKey) ?? false;
  }

  Future<DbConfig?> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return DbConfig.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConfig(DbConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(config.toJson()));
    await prefs.setBool(_configuredKey, true);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_configuredKey);
  }
}
