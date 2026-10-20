import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../models/auth_model.dart';
import 'auth_config.dart';
import 'auth_provider_interface.dart';

class _DemoOtpRecord {
  final String code;
  final DateTime expiresAt;
  final DateTime sentAt;
  int failedAttempts = 0;

  _DemoOtpRecord({
    required this.code,
    required this.expiresAt,
    required this.sentAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  int get remainingAttempts => max(0, 3 - failedAttempts);
}

/// Local in-memory DEMO authentication provider for development and testing
/// without an active Spring Boot backend.
class DemoAuthProvider implements AuthProvider {
  @override
  AuthMode get mode => AuthMode.demo;

  // Active OTP storage keyed by normalized identifier (phone or email)
  final Map<String, _DemoOtpRecord> _activeOtps = {};

  // Demo user database
  final List<Map<String, dynamic>> _demoUsers = [
    {
      'username': 'SuperAdmin',
      'email': 'admin@corpregistry.com',
      'password': 'companyAdmin',
      'fullName': 'System Administrator',
      'role': 'ROLE_ADMIN',
      'phone': '9876543210',
    },
    {
      'username': 'DemoUser',
      'email': 'user@corpregistry.com',
      'password': 'userPass123',
      'fullName': 'Enterprise Officer',
      'role': 'ROLE_USER',
      'phone': '9876543211',
    },
  ];

  // Securely bound biometric user for testing
  String? _boundBiometricUser;

  static const int _otpTtlSeconds = 120; // 2 minutes
  static const int _resendCooldownSeconds = 30; // 30 seconds
  static const int _maxAttempts = 3;

  @override
  Future<AuthResponse> loginWithPassword({
    required String usernameOrEmail,
    required String password,
  }) async {
    // Simulate realistic asynchronous network latency
    await Future.delayed(const Duration(milliseconds: 600));

    final normalized = usernameOrEmail.trim().toLowerCase();
    final matched = _demoUsers.firstWhere(
      (u) =>
          (u['username'].toString().toLowerCase() == normalized ||
              u['email'].toString().toLowerCase() == normalized) &&
          u['password'] == password,
      orElse: () => {},
    );

    if (matched.isEmpty) {
      throw Exception(
        'Invalid demo credentials. Use SuperAdmin / companyAdmin or register a demo user.',
      );
    }

    final token = _generateDemoToken(matched['username'] as String);
    return AuthResponse(
      token: token,
      tokenType: 'DemoBearer',
      username: matched['username'] as String,
      email: matched['email'] as String,
      fullName: matched['fullName'] as String,
      role: matched['role'] as String,
      expiresIn: 86400, // 24 hours
      isDemoSession: true,
    );
  }

  @override
  Future<AuthResponse> register(RegisterRequest request) async {
    await Future.delayed(const Duration(milliseconds: 650));

    final username = request.username.trim();
    final email = request.email.trim();

    // Check if user already exists
    final exists = _demoUsers.any(
      (u) =>
          u['username'].toString().toLowerCase() == username.toLowerCase() ||
          u['email'].toString().toLowerCase() == email.toLowerCase(),
    );

    if (exists) {
      throw Exception('Username or email already exists in demo registry.');
    }

    final newUser = {
      'username': username,
      'email': email,
      'password': request.password,
      'fullName': request.fullName.trim(),
      'role': 'ROLE_USER',
      'phone': '9990001111',
    };
    _demoUsers.add(newUser);

    final token = _generateDemoToken(username);
    return AuthResponse(
      token: token,
      tokenType: 'DemoBearer',
      username: username,
      email: email,
      fullName: request.fullName.trim(),
      role: 'ROLE_USER',
      expiresIn: 86400,
      isDemoSession: true,
    );
  }

  @override
  Future<OtpRequestResult> requestOtp({required String identifier}) async {
    await Future.delayed(const Duration(milliseconds: 450));

    final key = _normalizeIdentifier(identifier);
    if (key.isEmpty) {
      throw Exception('Please provide a valid phone number or email address.');
    }

    // Check resend cooldown
    final existing = _activeOtps[key];
    if (existing != null && !existing.isExpired) {
      final elapsed = DateTime.now().difference(existing.sentAt).inSeconds;
      if (elapsed < _resendCooldownSeconds) {
        final waitRemaining = _resendCooldownSeconds - elapsed;
        throw Exception(
          'Please wait $waitRemaining seconds before requesting another OTP.',
        );
      }
    }

    // Generate cryptographically secure-like 6-digit code
    final random = Random();
    final otpCode = (100000 + random.nextInt(900000)).toString();

    _activeOtps[key] = _DemoOtpRecord(
      code: otpCode,
      expiresAt: DateTime.now().add(const Duration(seconds: _otpTtlSeconds)),
      sentAt: DateTime.now(),
    );

    // In debug builds, provide debugOtpCode for visual development banner
    // In release builds, never expose it
    final debugCode = kDebugMode ? otpCode : null;

    return OtpRequestResult(
      success: true,
      message: 'Simulated 6-digit OTP generated for $identifier.',
      expiresInSeconds: _otpTtlSeconds,
      cooldownSeconds: _resendCooldownSeconds,
      debugOtpCode: debugCode,
      isSimulated: true,
    );
  }

  @override
  Future<AuthResponse> verifyOtp({
    required String identifier,
    required String otp,
  }) async {
    await Future.delayed(const Duration(milliseconds: 550));

    final key = _normalizeIdentifier(identifier);
    final record = _activeOtps[key];

    if (record == null) {
      throw Exception(
        'No active OTP found for this identifier. Please request a new code.',
      );
    }

    if (record.isExpired) {
      _activeOtps.remove(key);
      throw Exception(
        'The OTP code has expired. Please tap "Resend OTP" to generate a new code.',
      );
    }

    if (record.failedAttempts >= _maxAttempts) {
      _activeOtps.remove(key);
      throw Exception(
        'Maximum verification attempts exceeded. Please request a new OTP.',
      );
    }

    final trimmedInput = otp.trim();
    if (trimmedInput != record.code) {
      record.failedAttempts++;
      final remaining = record.remainingAttempts;
      if (remaining <= 0) {
        _activeOtps.remove(key);
        throw Exception(
          'Incorrect OTP. Maximum attempts exceeded. Please request a new code.',
        );
      }
      throw Exception(
        'Incorrect OTP code. $remaining attempt${remaining == 1 ? '' : 's'} remaining.',
      );
    }

    // Successful OTP verification
    _activeOtps.remove(key);

    // Find or create a demo user associated with this identifier
    var matchedUser = _demoUsers.firstWhere(
      (u) =>
          u['phone'] == key ||
          u['email'].toString().toLowerCase() == key.toLowerCase(),
      orElse: () => {},
    );

    if (matchedUser.isEmpty) {
      final isEmail = key.contains('@');
      final fallbackUsername = isEmail
          ? key.split('@').first
          : 'User_${key.substring(max(0, key.length - 4))}';
      matchedUser = {
        'username': fallbackUsername,
        'email': isEmail ? key : '$fallbackUsername@demo.corpregistry.com',
        'fullName': 'Verified Demo User',
        'role': 'ROLE_ADMIN',
        'phone': isEmail ? '9876543210' : key,
      };
      _demoUsers.add(matchedUser);
    }

    final username = matchedUser['username'] as String;
    final token = _generateDemoToken(username);

    return AuthResponse(
      token: token,
      tokenType: 'DemoBearer',
      username: username,
      email: matchedUser['email'] as String,
      fullName: matchedUser['fullName'] as String,
      role: matchedUser['role'] as String,
      expiresIn: 86400,
      isDemoSession: true,
    );
  }

  @override
  Future<UserProfile?> fetchCurrentUser(String? token) async {
    if (token == null || !token.startsWith('DEMO_SESSION_')) {
      return null;
    }
    final username = _extractUsernameFromToken(token);
    final user = _demoUsers.firstWhere(
      (u) => u['username'] == username,
      orElse: () => _demoUsers.first,
    );
    return UserProfile(
      username: user['username'] as String,
      email: user['email'] as String,
      fullName: user['fullName'] as String,
      role: user['role'] as String,
    );
  }

  @override
  Future<AuthResponse?> refreshSession(String? token) async {
    if (token == null) return null;
    final username = _extractUsernameFromToken(token);
    return AuthResponse(
      token: _generateDemoToken(username),
      tokenType: 'DemoBearer',
      username: username,
      email: '$username@corpregistry.com',
      fullName: username,
      role: 'ROLE_ADMIN',
      expiresIn: 86400,
      isDemoSession: true,
    );
  }

  @override
  Future<void> logout() async {
    // Clear in-memory demo OTP sessions
    _activeOtps.clear();
  }

  @override
  bool isTokenExpired(String? token) {
    if (token == null || token.isEmpty) return true;
    if (!token.startsWith('DEMO_SESSION_')) return true;
    try {
      final parts = token.split('_');
      if (parts.length >= 4) {
        final timestamp = int.tryParse(parts[3]);
        if (timestamp != null) {
          final creationTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          return DateTime.now().difference(creationTime).inHours >= 24;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Map<String, String> getAuthHeaders(
    String? token, [
    Map<String, String>? baseHeaders,
  ]) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-App-Mode': 'DEMO',
      ...?baseHeaders,
    };
    if (token != null && token.isNotEmpty) {
      headers['X-Demo-Session'] = token;
    }
    return headers;
  }

  @override
  Future<AuthResponse> authenticateWithBiometrics({
    required String username,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final targetUser = _boundBiometricUser ?? username;
    final user = _demoUsers.firstWhere(
      (u) => u['username'].toString().toLowerCase() == targetUser.toLowerCase(),
      orElse: () => _demoUsers.first,
    );

    final token = _generateDemoToken(user['username'] as String);
    return AuthResponse(
      token: token,
      tokenType: 'DemoBearer',
      username: user['username'] as String,
      email: user['email'] as String,
      fullName: user['fullName'] as String,
      role: user['role'] as String,
      expiresIn: 86400,
      isDemoSession: true,
    );
  }

  @override
  Future<void> registerBiometricCredential({
    required String username,
    required String sessionToken,
  }) async {
    _boundBiometricUser = username;
  }

  @override
  Future<void> revokeBiometricCredential() async {
    _boundBiometricUser = null;
  }

  String _normalizeIdentifier(String raw) {
    return raw.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  String _generateDemoToken(String username) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = Random().nextInt(999999);
    final payload = base64Url.encode(
      utf8.encode('$username:$now:$randomSuffix'),
    );
    return 'DEMO_SESSION_${username}_${now}_$payload';
  }

  String _extractUsernameFromToken(String token) {
    try {
      final parts = token.split('_');
      if (parts.length >= 3) return parts[2];
    } catch (_) {}
    return 'SuperAdmin';
  }
}
