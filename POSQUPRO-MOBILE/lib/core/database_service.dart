import 'package:mysql_client/mysql_client.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  MySQLConnection? _connection;

  Future<MySQLConnection> get connection async {
    if (_connection != null && _connection!.connected) return _connection!;

    _connection = await MySQLConnection.createConnection(
      host: '127.0.0.1',
      port: 3306,
      userName: 'root',
      password: 'khotibul185\$\$',
      databaseName: 'posqu_pro_desktop',
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
