import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const Duration _timeout = Duration(seconds: 20);

  String? _token;
  String _baseUrl = AppConstants.defaultBaseUrl;

  String get baseUrl => _baseUrl;

  /// Menormalkan URL server: selalu memakai skema http/https dan berakhiran
  /// `/api`. Ini mencegah kesalahan umum seperti `posqupro.co-id.id` tanpa
  /// skema atau `https://host/api/` dengan garis miring ganda.
  static String normalizeBaseUrl(String url) {
    var value = url.trim();
    if (value.isEmpty) return AppConstants.defaultBaseUrl;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    value = value.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(value);
    if (uri == null) return AppConstants.defaultBaseUrl;
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (path.isEmpty) return '$value/api';
    return value;
  }

  void setToken(String? token) {
    _token = token;
  }

  void setBaseUrl(String url) {
    final normalized = normalizeBaseUrl(url);
    _baseUrl = normalized;
    ApiConstants.baseUrl = normalized;
  }

  void initFromConfig(String baseUrl) {
    setBaseUrl(baseUrl);
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.tokenKey);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request, {
    bool retry = false,
  }) async {
    var attempts = retry ? 2 : 1;
    Object? lastError;
    while (attempts > 0) {
      attempts--;
      try {
        final response = await request().timeout(_timeout);
        return _handleResponse(response);
      } on TimeoutException {
        lastError = 'timeout';
        if (attempts == 0) {
          return {
            'success': false,
            'message': 'Koneksi timeout. Periksa jaringan internet Anda.',
          };
        }
      } on SocketException {
        return {
          'success': false,
          'message': 'Tidak ada koneksi internet atau server tidak terjangkau.',
        };
      } on http.ClientException {
        lastError = 'client';
        if (attempts == 0) {
          return {
            'success': false,
            'message': 'Gagal terhubung ke server. Periksa alamat server Anda.',
          };
        }
      } catch (e) {
        return {'success': false, 'message': 'Terjadi kesalahan: $e'};
      }
    }
    return {
      'success': false,
      'message': lastError == 'timeout'
          ? 'Koneksi timeout. Periksa jaringan internet Anda.'
          : 'Gagal terhubung ke server.',
    };
  }

  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? queryParams}) {
    return _send(
      () async {
        final uri = Uri.parse('$_baseUrl$endpoint').replace(queryParameters: queryParams);
        return http.get(uri, headers: await _headers()).timeout(_timeout);
      },
      retry: true,
    );
  }

  Future<Map<String, dynamic>> post(String endpoint, {Map<String, dynamic>? body}) {
    return _send(() async {
      return http
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: await _headers(),
            body: jsonEncode(body ?? {}),
          )
          .timeout(_timeout);
    });
  }

  Future<Map<String, dynamic>> put(String endpoint, {Map<String, dynamic>? body}) {
    return _send(() async {
      return http
          .put(
            Uri.parse('$_baseUrl$endpoint'),
            headers: await _headers(),
            body: jsonEncode(body ?? {}),
          )
          .timeout(_timeout);
    });
  }

  Future<Map<String, dynamic>> delete(String endpoint) {
    return _send(() async {
      return http.delete(Uri.parse('$_baseUrl$endpoint'), headers: await _headers()).timeout(_timeout);
    });
  }

  Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    required String fileField,
    required String filePath,
    Map<String, String>? fields,
  }) {
    return _send(() async {
      final headers = await _headers();
      headers.remove('Content-Type'); // http menambahkan boundary sendiri
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl$endpoint'))
        ..headers.addAll(headers);
      if (fields != null) request.fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
      final streamed = await request.send().timeout(_timeout);
      return http.Response.fromStream(streamed);
    });
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    dynamic body;
    try {
      body = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    } catch (_) {
      body = <String, dynamic>{};
    }
    if (body is! Map) body = <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {'success': true, 'data': body};
    }

    if (response.statusCode == 401) {
      return {
        'success': false,
        'message': body['message'] ?? 'Unauthorized',
        'unauthorized': true,
      };
    }

    // Laravel mengirim pesan validasi spesifik di `errors`. Tampilkan pesan
    // pertama (mis. stok tidak cukup) agar kasir tahu penyebab kegagalan.
    String? validationMessage;
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        validationMessage = first.first?.toString();
      } else if (first != null) {
        validationMessage = first.toString();
      }
    }

    return {
      'success': false,
      'message': validationMessage ?? body['message'] ?? 'Terjadi kesalahan',
      'errors': errors,
    };
  }
}
