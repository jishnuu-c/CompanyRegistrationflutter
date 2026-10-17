import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiConfig extends ChangeNotifier {
  static final ApiConfig _instance = ApiConfig._internal();
  factory ApiConfig() => _instance;

  String _host = '';
  bool _isOnline = false;
  bool _isChecking = false;
  String _lastError = '';

  ApiConfig._internal() {
    _initDefaultHost();
  }

  void _initDefaultHost() {
    // Default backend server matching Angular environment.ts
    _host = 'http://192.168.1.142:8080';
    // _host = 'http://103.199.210.172:8080';
    // _host = 'http://192.168.1.201:8080';
    checkConnection();
  }

  String get host => _host;
  String get apiUrl => '$_host/api/company-app';
  String get fileBaseUrl => '$_host/';
  bool get isOnline => _isOnline;
  bool get isChecking => _isChecking;
  String get lastError => _lastError;

  void setOnline(bool online) {
    _isOnline = online;
    if (online) _lastError = '';
    notifyListeners();
  }

  void setHost(String newHost) {
    var trimmed = newHost.trim().replaceAll(RegExp(r'/+$'), '');
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    _host = trimmed;
    notifyListeners();
    checkConnection();
  }

  Future<bool> checkConnection() async {
    _isChecking = true;
    _lastError = '';

    try {
      // Lightweight probe to verify server is reachable
      final endpoint = Uri.parse('$apiUrl/companies/get-all');
      final response = await http
          .get(endpoint)
          .timeout(const Duration(seconds: 3));

      // Any HTTP response (including 200, 401, 403) confirms the backend server is reachable
      if (response.statusCode != 502 &&
          response.statusCode != 503 &&
          response.statusCode != 504) {
        _isOnline = true;
        _lastError = '';
      } else {
        _isOnline = false;
        _lastError = 'Gateway error (${response.statusCode})';
      }
    } catch (e) {
      _isOnline = false;
      _lastError = e.toString();
    } finally {
      _isChecking = false;
      notifyListeners();
    }
    return _isOnline;
  }

  String getFileUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      // If path contains localhost or 127.0.0.1, rewrite to current host for mobile devices
      if (_host.isNotEmpty &&
          (path.contains('://localhost') || path.contains('://127.0.0.1'))) {
        final uri = Uri.tryParse(path);
        if (uri != null) {
          final hostUri = Uri.tryParse(_host);
          if (hostUri != null) {
            return uri
                .replace(
                  scheme: hostUri.scheme,
                  host: hostUri.host,
                  port: hostUri.port,
                )
                .toString();
          }
        }
      }
      return path;
    }
    var cleanPath = path.replaceAll('\\', '/');
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }
    return '$fileBaseUrl$cleanPath';
  }
}
