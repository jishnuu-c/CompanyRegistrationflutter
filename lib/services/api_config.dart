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
    // Default to the actual network backend server matching Angular environment.ts
    _host = 'http://192.168.1.201:8080';
    // _host = 'http://103.199.210.172:8080';
    checkConnection();
  }

  String get host => _host;
  String get apiUrl => '$_host/api/company-app';
  String get fileBaseUrl => '$_host/';
  bool get isOnline => _isOnline;
  bool get isChecking => _isChecking;
  String get lastError => _lastError;

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
    notifyListeners();

    try {
      final endpoint = Uri.parse('$apiUrl/companies/get-all');
      final response = await http
          .get(endpoint)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode >= 200 && response.statusCode < 400) {
        _isOnline = true;
        _lastError = '';
      } else {
        _isOnline = response.statusCode != 502 && response.statusCode != 503;
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
      return path;
    }
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$fileBaseUrl$cleanPath';
  }
}
