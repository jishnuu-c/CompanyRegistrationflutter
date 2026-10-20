import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Supported authentication operational modes
enum AuthMode { demo, api }

/// Central configuration for authentication mode selection (DEMO vs API)
class AppAuthConfig extends ChangeNotifier {
  static final AppAuthConfig _instance = AppAuthConfig._internal();
  factory AppAuthConfig() => _instance;

  static const String _storageKeyAuthMode = 'app_auth_mode';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // DEMO mode is enabled by default as requested
  AuthMode _mode = AuthMode.demo;
  bool _initialized = false;

  AppAuthConfig._internal() {
    _loadSavedMode();
  }

  AuthMode get mode => _mode;
  bool get isDemoMode => _mode == AuthMode.demo;
  bool get isApiMode => _mode == AuthMode.api;
  bool get isInitialized => _initialized;

  Future<void> _loadSavedMode() async {
    try {
      final saved = await _storage.read(key: _storageKeyAuthMode);
      if (saved != null) {
        if (saved == 'api') {
          _mode = AuthMode.api;
        } else {
          _mode = AuthMode.demo;
        }
      }
    } catch (_) {
      // Fallback default is demo
      _mode = AuthMode.demo;
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  /// Change authentication mode explicitly
  Future<void> setMode(AuthMode newMode) async {
    if (_mode == newMode) return;
    _mode = newMode;
    notifyListeners();
    try {
      await _storage.write(
        key: _storageKeyAuthMode,
        value: newMode == AuthMode.api ? 'api' : 'demo',
      );
    } catch (_) {}
  }

  /// Toggle between Demo and API mode
  Future<void> toggleMode() async {
    await setMode(isDemoMode ? AuthMode.api : AuthMode.demo);
  }
}
