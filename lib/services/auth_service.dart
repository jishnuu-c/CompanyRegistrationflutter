import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/auth_model.dart';
import 'api_config.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final ApiConfig _apiConfig = ApiConfig();

  String? _token;
  UserProfile? _currentUser;

  AuthService._internal();

  String? get token => _token;
  UserProfile? get currentUser => _currentUser;

  bool get isLoggedIn {
    final t = _token;
    return t != null && t.isNotEmpty && !isTokenExpired(t);
  }

  String get authBaseUrl => '${_apiConfig.host}/api/auth';

  /// Authenticate with username/email and password against Spring Boot backend
  Future<AuthResponse> login(String usernameOrEmail, String password) async {
    final uri = Uri.parse('$authBaseUrl/login');
    final reqBody = jsonEncode(LoginRequest(
      usernameOrEmail: usernameOrEmail.trim(),
      password: password,
    ).toJson());

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: reqBody,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final authResponse = AuthResponse.fromJson(data);

        _token = authResponse.token;
        _currentUser = authResponse.toUserProfile();
        notifyListeners();

        // Also test connection state in ApiConfig
        _apiConfig.checkConnection();

        return authResponse;
      } else if (response.statusCode == 401) {
        String msg = 'Invalid username/email or password. Please verify credentials.';
        try {
          final errBody = jsonDecode(utf8.decode(response.bodyBytes));
          if (errBody is Map && errBody['message'] != null) {
            msg = errBody['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      } else if (response.statusCode == 403) {
        String msg = 'Access forbidden. Your account may be disabled or pending review.';
        try {
          final errBody = jsonDecode(utf8.decode(response.bodyBytes));
          if (errBody is Map && errBody['message'] != null) {
            msg = errBody['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      } else {
        String msg = 'Authentication failed (Status: ${response.statusCode}).';
        try {
          final errBody = jsonDecode(utf8.decode(response.bodyBytes));
          if (errBody is Map && errBody['message'] != null) {
            msg = errBody['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      if (e is Exception && !e.toString().startsWith('Exception: Authentication failed')) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        if (msg.contains('SocketException') ||
            msg.contains('Connection refused') ||
            msg.contains('ClientException') ||
            msg.contains('Failed host lookup') ||
            msg.contains('timed out')) {
          throw Exception(
              'Authentication failed. Please verify that the server is online at ${_apiConfig.host}.');
        }
        throw Exception(msg);
      }
      rethrow;
    }
  }

  /// Silently fetch user profile using Bearer token
  Future<UserProfile?> fetchCurrentUser() async {
    if (_token == null || isTokenExpired(_token)) {
      return null;
    }

    try {
      final uri = Uri.parse('$authBaseUrl/me');
      final response = await http.get(
        uri,
        headers: getAuthHeaders(),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        _currentUser = UserProfile.fromJson(data);
        notifyListeners();
        return _currentUser;
      } else if (response.statusCode == 401) {
        logout();
      }
    } catch (_) {}
    return null;
  }

  /// Sign out current user
  void logout() {
    _token = null;
    _currentUser = null;
    notifyListeners();
  }

  /// Validate JWT token expiration locally
  bool isTokenExpired(String? jwtToken) {
    if (jwtToken == null || jwtToken.isEmpty) return true;
    try {
      final parts = jwtToken.split('.');
      if (parts.length != 3) return true;

      final normalized = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> payload = jsonDecode(payloadString);

      if (!payload.containsKey('exp')) return false;

      final exp = payload['exp'];
      if (exp is int) {
        final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        return DateTime.now().isAfter(expDate);
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  /// Returns headers with Bearer token injected if available
  Map<String, String> getAuthHeaders([Map<String, String>? baseHeaders]) {
    final headers = <String, String>{
      'Accept': 'application/json',
      ...?baseHeaders,
    };
    if (_token != null && _token!.isNotEmpty && !isTokenExpired(_token)) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }
}
