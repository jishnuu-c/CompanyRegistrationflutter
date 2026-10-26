import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/auth_model.dart';
import '../api_config.dart';
import 'auth_config.dart';
import 'auth_provider_interface.dart';

/// Production API authentication provider connecting to Spring Boot backend.
/// When the Spring Boot backend is ready, this provider handles live network requests.
class ApiAuthProvider implements AuthProvider {
  final ApiConfig _apiConfig = ApiConfig();

  @override
  AuthMode get mode => AuthMode.api;

  String get authBaseUrl => '${_apiConfig.host}/api/auth';

  @override
  Future<AuthResponse> loginWithPassword({
    required String usernameOrEmail,
    required String password,
  }) async {
    final uri = Uri.parse('$authBaseUrl/login');
    final reqBody = jsonEncode(
      LoginRequest(
        usernameOrEmail: usernameOrEmail.trim(),
        password: password,
      ).toJson(),
    );

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
        _apiConfig.setOnline(true);
        return authResponse;
      } else if (response.statusCode == 401) {
        String msg =
            'Invalid username/email or password. Please verify credentials.';
        try {
          final errBody = jsonDecode(utf8.decode(response.bodyBytes));
          if (errBody is Map && errBody['message'] != null) {
            msg = errBody['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      } else if (response.statusCode == 403) {
        String msg =
            'Access forbidden. Your account may be disabled or pending review.';
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
      if (e is Exception &&
          !e.toString().startsWith('Exception: Authentication failed')) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        if (msg.contains('SocketException') ||
            msg.contains('Connection refused') ||
            msg.contains('ClientException') ||
            msg.contains('Failed host lookup') ||
            msg.contains('timed out')) {
          throw Exception(
            'Authentication failed. Unable to reach corporate server. Please check your network connection and try again.',
          );
        }
        throw Exception(msg);
      }
      rethrow;
    }
  }

  @override
  Future<AuthResponse> register(RegisterRequest request) async {
    final uri = Uri.parse('$authBaseUrl/register');
    final reqBody = jsonEncode(request.toJson());

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
        _apiConfig.setOnline(true);
        return authResponse;
      } else if (response.statusCode == 400) {
        String msg =
            'Invalid registration details. Please verify the input fields.';
        try {
          final errBody = jsonDecode(utf8.decode(response.bodyBytes));
          if (errBody is Map) {
            if (errBody['message'] != null && errBody['message'].toString().trim().isNotEmpty) {
              msg = errBody['message'].toString();
            } else if (errBody['errors'] != null) {
              if (errBody['errors'] is Map) {
                final firstErr = (errBody['errors'] as Map).values.firstOrNull;
                if (firstErr != null) msg = firstErr.toString();
              } else if (errBody['errors'] is List) {
                final firstErr = (errBody['errors'] as List).firstOrNull;
                if (firstErr != null) msg = firstErr.toString();
              }
            }
          }
        } catch (_) {}
        throw Exception(msg);
      } else {
        String msg = 'Registration failed (Status: ${response.statusCode}).';
        try {
          final errBody = jsonDecode(utf8.decode(response.bodyBytes));
          if (errBody is Map) {
            if (errBody['message'] != null && errBody['message'].toString().trim().isNotEmpty) {
              msg = errBody['message'].toString();
            } else if (errBody['errors'] != null) {
              if (errBody['errors'] is Map) {
                final firstErr = (errBody['errors'] as Map).values.firstOrNull;
                if (firstErr != null) msg = firstErr.toString();
              } else if (errBody['errors'] is List) {
                final firstErr = (errBody['errors'] as List).firstOrNull;
                if (firstErr != null) msg = firstErr.toString();
              }
            }
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      if (e is Exception &&
          !e.toString().startsWith('Exception: Registration failed')) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        if (msg.contains('SocketException') ||
            msg.contains('Connection refused') ||
            msg.contains('ClientException') ||
            msg.contains('Failed host lookup') ||
            msg.contains('timed out')) {
          throw Exception(
            'Registration failed. Unable to reach corporate server. Please check your network connection and try again.',
          );
        }
        throw Exception(msg);
      }
      rethrow;
    }
  }

  @override
  Future<OtpRequestResult> requestOtp({required String identifier}) async {
    final uri = Uri.parse('$authBaseUrl/otp/request');
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'identifier': identifier.trim()}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return OtpRequestResult(
          success: true,
          message:
              data['message']?.toString() ??
              'OTP sent successfully to $identifier',
          expiresInSeconds: data['expiresInSeconds'] as int? ?? 120,
          cooldownSeconds: data['cooldownSeconds'] as int? ?? 30,
          isSimulated: false,
        );
      } else {
        String errorMsg =
            'Failed to request OTP from server (${response.statusCode})';
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['message'] != null) errorMsg = data['message'].toString();
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      // If backend OTP endpoint is not yet deployed, provide clear documentation feedback
      if (e.toString().contains('404') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('SocketException')) {
        throw Exception(
          'Spring Boot OTP service is not available at $authBaseUrl/otp/request. '
          'Please switch to DEMO mode for OTP testing until backend endpoints are deployed.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<AuthResponse> verifyOtp({
    required String identifier,
    required String otp,
  }) async {
    final uri = Uri.parse('$authBaseUrl/otp/verify');
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'identifier': identifier.trim(),
              'otp': otp.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return AuthResponse.fromJson(data);
      } else {
        String errorMsg = 'Invalid or expired OTP.';
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['message'] != null) errorMsg = data['message'].toString();
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e.toString().contains('404') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('SocketException')) {
        throw Exception(
          'Spring Boot OTP verification endpoint is not yet available at $authBaseUrl/otp/verify. '
          'Please switch to DEMO mode for testing.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<UserProfile?> fetchCurrentUser(String? token) async {
    if (token == null || isTokenExpired(token)) {
      return null;
    }

    try {
      final uri = Uri.parse('$authBaseUrl/me');
      final response = await http
          .get(uri, headers: getAuthHeaders(token))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return UserProfile.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<AuthResponse?> refreshSession(String? token) async {
    if (token == null || isTokenExpired(token)) return null;
    try {
      final uri = Uri.parse('$authBaseUrl/refresh');
      final response = await http
          .post(uri, headers: getAuthHeaders(token))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return AuthResponse.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> logout() async {
    // Optionally notify server of session revocation
    try {
      final uri = Uri.parse('$authBaseUrl/logout');
      await http.post(uri).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  @override
  bool isTokenExpired(String? token) {
    if (token == null || token.isEmpty) return true;
    try {
      final parts = token.split('.');
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

  @override
  Map<String, String> getAuthHeaders(
    String? token, [
    Map<String, String>? baseHeaders,
  ]) {
    final headers = <String, String>{
      'Accept': 'application/json',
      ...?baseHeaders,
    };
    if (token != null && token.isNotEmpty && !isTokenExpired(token)) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  @override
  Future<AuthResponse> authenticateWithBiometrics({
    required String username,
  }) async {
    // In API mode, biometrics submits cryptographic challenge or refresh token
    final uri = Uri.parse('$authBaseUrl/biometrics/authenticate');
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'username': username}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return AuthResponse.fromJson(data);
      } else {
        throw Exception('Biometric authentication token rejected by server.');
      }
    } catch (e) {
      if (e.toString().contains('404') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('SocketException')) {
        throw Exception(
          'Spring Boot Biometric endpoint is not deployed yet at $authBaseUrl/biometrics/authenticate. '
          'Please test in DEMO mode.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> registerBiometricCredential({
    required String username,
    required String sessionToken,
  }) async {
    final uri = Uri.parse('$authBaseUrl/biometrics/register');
    try {
      await http
          .post(
            uri,
            headers: getAuthHeaders(sessionToken, {
              'Content-Type': 'application/json',
            }),
            body: jsonEncode({'username': username}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Non-fatal if server endpoint not yet implemented
    }
  }

  @override
  Future<void> revokeBiometricCredential() async {
    final uri = Uri.parse('$authBaseUrl/biometrics/revoke');
    try {
      await http.post(uri).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}
