import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_model.dart';
import 'api_config.dart';
import 'auth/api_auth_provider.dart';
import 'auth/auth_config.dart';
import 'auth/auth_provider_interface.dart';
import 'auth/biometric_service.dart';
import 'auth/demo_auth_provider.dart';

/// Central Authentication Service connecting application UI and domain services
/// to the active authentication provider (Demo or API) with full support for
/// passwords, OTP verification, and real device biometric authentication.
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final AppAuthConfig _authConfig = AppAuthConfig();
  final ApiConfig _apiConfig = ApiConfig();
  final BiometricService _biometricService = BiometricService();

  late final DemoAuthProvider _demoProvider;
  late final ApiAuthProvider _apiProvider;

  static const String _storageKeyToken = 'cr_auth_token';
  static const String _storageKeyUser = 'cr_auth_user';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _token;
  UserProfile? _currentUser;
  bool _isDemoSession = false;

  AuthService._internal() {
    _demoProvider = DemoAuthProvider();
    _apiProvider = ApiAuthProvider();

    _authConfig.addListener(_onAuthConfigChanged);
    _restoreStoredSession();
  }

  Future<void> _restoreStoredSession() async {
    try {
      final savedToken = await _secureStorage.read(key: _storageKeyToken);
      if (savedToken != null &&
          savedToken.isNotEmpty &&
          !isTokenExpired(savedToken)) {
        _token = savedToken;
        _isDemoSession =
            savedToken.startsWith('DEMO_SESSION_') || _authConfig.isDemoMode;
        final savedUserJson = await _secureStorage.read(key: _storageKeyUser);
        if (savedUserJson != null && savedUserJson.isNotEmpty) {
          try {
            _currentUser = UserProfile.fromJson(jsonDecode(savedUserJson));
          } catch (_) {}
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  void _persistSession(AuthResponse response) {
    _token = response.token;
    _currentUser = response.toUserProfile();
    _isDemoSession = response.isDemoSession;
    notifyListeners();

    if (response.token.isNotEmpty) {
      _secureStorage
          .write(key: _storageKeyToken, value: response.token)
          .catchError((_) {});
    }
    if (_currentUser != null) {
      _secureStorage
          .write(
            key: _storageKeyUser,
            value: jsonEncode(_currentUser!.toJson()),
          )
          .catchError((_) {});
    }
  }

  void _onAuthConfigChanged() {
    notifyListeners();
  }

  /// Active authentication provider based on current mode
  AuthProvider get currentProvider =>
      _authConfig.isDemoMode ? _demoProvider : _apiProvider;

  AuthMode get authMode => _authConfig.mode;
  bool get isDemoMode => _authConfig.isDemoMode;
  bool get isDemoSession => _isDemoSession;

  String? get token => _token;
  UserProfile? get currentUser => _currentUser;

  bool get isLoggedIn {
    final t = _token;
    if (t == null || t.isEmpty) return false;
    return !isTokenExpired(t);
  }

  String get authBaseUrl => '${_apiConfig.host}/api/auth';

  /// Switch authentication mode between DEMO and API
  Future<void> setAuthMode(AuthMode mode) async {
    if (_authConfig.mode == mode) return;
    logout();
    await _authConfig.setMode(mode);
  }

  /// Authenticate with username/email and password using the active provider
  Future<AuthResponse> login(String usernameOrEmail, String password) async {
    final response = await currentProvider.loginWithPassword(
      usernameOrEmail: usernameOrEmail,
      password: password,
    );

    _persistSession(response);
    return response;
  }

  /// Register a new account using the active provider
  Future<AuthResponse> register(RegisterRequest req) async {
    final response = await currentProvider.register(req);

    _persistSession(response);
    return response;
  }

  /// Request a 6-digit OTP to be delivered to the specified phone or email
  Future<OtpRequestResult> requestOtp(String identifier) async {
    return await currentProvider.requestOtp(identifier: identifier);
  }

  /// Verify 6-digit OTP code and establish user session
  Future<AuthResponse> verifyOtp(String identifier, String otp) async {
    final response = await currentProvider.verifyOtp(
      identifier: identifier,
      otp: otp,
    );

    _persistSession(response);
    return response;
  }

  /// Query device biometric hardware capabilities and user enrollment state
  Future<BiometricCapabilities> checkBiometrics() async {
    return await _biometricService.getCapabilities();
  }

  /// Perform native OS biometric prompt and authenticate session for bound user.
  /// Strictly requires real operating-system authentication success.
  Future<AuthResponse> authenticateWithBiometrics() async {
    final isEnabled = await _biometricService.isBiometricLoginEnabled();
    final boundUser = await _biometricService.getBoundUsername();
    if (!isEnabled || boundUser == null || boundUser.isEmpty) {
      throw Exception(
        'Biometric authentication is not enabled for any user on this device. Please log in first and enable biometrics.',
      );
    }

    if (isDemoMode) {
      final isValidDemoUser = _demoProvider.hasDemoUser(boundUser);
      if (!isValidDemoUser) {
        throw Exception(
          'Bound demo user "$boundUser" is not recognized in demo mode. Please log in with your demo account first.',
        );
      }
    }

    final caps = await _biometricService.getCapabilities();
    final promptReason = caps.isFaceOnly
        ? 'Verify your face to access CorpRegistry portal as $boundUser'
        : (caps.isFingerprintOnly
              ? 'Scan your fingerprint to access CorpRegistry portal as $boundUser'
              : 'Authenticate to access CorpRegistry portal as $boundUser');

    final result = await _biometricService.authenticate(reason: promptReason);

    if (!result.success) {
      if (result.isCancelled) {
        throw Exception('Biometric verification cancelled.');
      }
      throw Exception(
        result.errorMessage ?? 'Biometric authentication failed.',
      );
    }

    // Native OS prompt succeeded! Authenticate with active provider
    final response = await currentProvider.authenticateWithBiometrics(
      username: boundUser,
    );

    _persistSession(response);
    return response;
  }

  /// Enable biometric login for a specific user after explicit consent
  Future<void> enableBiometricsForUser(
    String username, {
    String? biometricType,
  }) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) {
      throw ArgumentError(
        'Username cannot be empty when enabling biometric login.',
      );
    }

    // In demo or API mode, register credential with active provider first
    if (_token != null) {
      await currentProvider.registerBiometricCredential(
        username: cleanUsername,
        sessionToken: _token!,
      );
    }

    // Securely persist to local secure storage atomically
    try {
      await _biometricService.enableBiometricLogin(
        cleanUsername,
        biometricType: biometricType,
      );
    } catch (e) {
      // Rollback provider credential if local storage failed to prevent partial state
      try {
        await currentProvider.revokeBiometricCredential();
      } catch (_) {}
      rethrow;
    }

    notifyListeners();
  }

  /// Check whether the specified demo username exists in the demo registry
  bool isBoundDemoUserValid(String? username) {
    if (username == null || username.trim().isEmpty) return false;
    return _demoProvider.hasDemoUser(username);
  }

  /// Disable biometric login on this device
  Future<void> disableBiometrics() async {
    await _biometricService.disableBiometricLogin();
    await currentProvider.revokeBiometricCredential();
    notifyListeners();
  }

  Future<bool> isBiometricsEnabled() async {
    return await _biometricService.isBiometricLoginEnabled();
  }

  Future<String?> getBiometricUsername() async {
    return await _biometricService.getBoundUsername();
  }

  /// Fetch user profile using active session
  Future<UserProfile?> fetchCurrentUser() async {
    if (_token == null || isTokenExpired(_token)) {
      return null;
    }

    final profile = await currentProvider.fetchCurrentUser(_token);
    if (profile != null) {
      _currentUser = profile;
      notifyListeners();
      return _currentUser;
    } else if (!_isDemoSession) {
      logout();
    }
    return null;
  }

  /// Sign out current user and clear local session state
  void logout() {
    _token = null;
    _currentUser = null;
    _isDemoSession = false;
    currentProvider.logout();
    _secureStorage.delete(key: _storageKeyToken).catchError((_) {});
    _secureStorage.delete(key: _storageKeyUser).catchError((_) {});
    notifyListeners();
  }

  /// Check whether the token is expired
  bool isTokenExpired(String? jwtToken) {
    if (jwtToken == null || jwtToken.isEmpty) return true;
    return currentProvider.isTokenExpired(jwtToken);
  }

  /// Returns headers with authorization credentials injected safely
  Map<String, String> getAuthHeaders([Map<String, String>? baseHeaders]) {
    final headers = <String, String>{
      'Accept': 'application/json',
      ...?baseHeaders,
    };

    if (_token != null && _token!.isNotEmpty && !isTokenExpired(_token)) {
      headers['Authorization'] = 'Bearer $_token';
      if (_isDemoSession) {
        headers['X-Demo-Session'] = _token!;
        headers['X-App-Mode'] = 'DEMO';
      }
    }
    return headers;
  }
}
