class DbConfig {
  final String mode; // offline|wifi|hosting
  final String name;
  final String host;
  final int port;
  final String user;
  final String password;
  final String database;
  final String apiBaseUrl;
  final String apiBasePath;

  const DbConfig({
    required this.mode,
    required this.name,
    required this.host,
    required this.port,
    required this.user,
    required this.password,
    required this.database,
    required this.apiBaseUrl,
    required this.apiBasePath,
  });

  factory DbConfig.offline() {
    return const DbConfig(
      mode: 'offline',
      name: 'Offline (Perangkat)',
      host: '',
      port: 0,
      user: '',
      password: '',
      database: '',
      apiBaseUrl: '',
      apiBasePath: '/api',
    );
  }

  factory DbConfig.wifi(String host) {
    return DbConfig(
      mode: 'wifi',
      name: 'WiFi LAN (PC Server)',
      host: host,
      port: 3306,
      user: 'root',
      password: 'khotibul185\$\$',
      database: 'posqu_pro_desktop',
      apiBaseUrl: 'http://$host:8000/api',
      apiBasePath: '/api',
    );
  }

  factory DbConfig.hosting(String host) {
    // gunakan http/https sesuai host; default asumsi HTTP kecuali ada :443
    final url = host.startsWith('http') ? host : 'https://$host';
    return DbConfig(
      mode: 'hosting',
      name: 'Online Hosting',
      host: host.replaceFirst(RegExp(r'^https?://'), ''),
      port: 0,
      user: '',
      password: '',
      database: '',
      apiBaseUrl: url.endsWith('/api') ? url : '$url/api',
      apiBasePath: '/api',
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'name': name,
        'host': host,
        'port': port,
        'user': user,
        'password': password,
        'database': database,
        'apiBaseUrl': apiBaseUrl,
        'apiBasePath': apiBasePath,
      };

  factory DbConfig.fromJson(Map<String, dynamic> json) => DbConfig(
        mode: json['mode'] ?? 'hosting',
        name: json['name'] ?? '',
        host: json['host'] ?? '',
        port: json['port'] ?? 0,
        user: json['user'] ?? '',
        password: json['password'] ?? '',
        database: json['database'] ?? '',
        apiBaseUrl: json['apiBaseUrl'] ?? '',
        apiBasePath: json['apiBasePath'] ?? '/api',
      );
}
