import 'package:mysql_client/mysql_client.dart';
import '../models/db_config.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  MySQLConnection? _connection;
  DbConfig? _config;

  void setConfig(DbConfig config) {
    _config = config;
    _connection = null;
  }

  DbConfig? get config => _config;

  Future<MySQLConnection> get connection async {
    if (_connection != null && _connection!.connected) return _connection!;

    final cfg = _config;
    if (cfg == null || cfg.mode != 'wifi') {
      throw Exception('DatabaseService hanya untuk mode WiFi/LAN');
    }

    _connection = await MySQLConnection.createConnection(
      host: cfg.host,
      port: cfg.port,
      userName: cfg.user,
      password: cfg.password,
      databaseName: cfg.database,
    );

    await _connection!.connect();
    return _connection!;
  }

  Future<void> disconnect() async {
    if (_connection != null && _connection!.connected) {
      await _connection!.close();
      _connection = null;
    }
  }

  Future<List<Map<String, dynamic>>> query(String sql, [Map<String, dynamic>? params]) async {
    final conn = await connection;
    final result = await conn.execute(sql, params ?? {});
    return result.rows.map((row) => row.assoc()).toList();
  }

  Future<Map<String, dynamic>?> queryOne(String sql, [Map<String, dynamic>? params]) async {
    final rows = await query(sql, params);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> execute(String sql, [Map<String, dynamic>? params]) async {
    final conn = await connection;
    final result = await conn.execute(sql, params ?? {});
    return result.affectedRows.toInt();
  }
}
