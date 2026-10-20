import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../models/auth_model.dart';

/// Detailed result of a native biometric authentication operation
class BiometricAuthResult {
  final bool success;
  final String? errorMessage;
  final bool isCancelled;
  final String? errorCode;

  const BiometricAuthResult({
    required this.success,
    this.errorMessage,
    this.isCancelled = false,
    this.errorCode,
  });

  factory BiometricAuthResult.successful() =>
      const BiometricAuthResult(success: true);

  factory BiometricAuthResult.cancelled() => const BiometricAuthResult(
    success: false,
    isCancelled: true,
    errorMessage: 'Biometric verification cancelled.',
  );

  factory BiometricAuthResult.failure(String message, [String? code]) =>
      BiometricAuthResult(
        success: false,
        errorMessage: message,
        errorCode: code,
      );
}

/// Service handling real device biometric hardware detection, enrollment checks,
/// native OS authentication prompt, and secure credential binding storage.
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _keyBiometricEnabled = 'biometric_auth_enabled';
  static const String _keyBiometricUsername = 'biometric_bound_username';

  BiometricService._internal();

  /// Check hardware support and enrollment state on the physical/simulated device
  Future<BiometricCapabilities> getCapabilities() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();

      final hasFingerprint =
          available.contains(BiometricType.fingerprint) ||
          available.contains(BiometricType.strong) ||
          available.contains(BiometricType.weak);

      final hasFace = available.contains(BiometricType.face);
      final hasIris = available.contains(BiometricType.iris);

      final isEnrolled = available.isNotEmpty;
      final isEnabled = await isBiometricLoginEnabled();
      final boundUser = await getBoundUsername();

      return BiometricCapabilities(
        isSupported: isSupported,
        canCheckBiometrics: canCheck,
        hasFingerprint: hasFingerprint,
        hasFace: hasFace,
        hasIris: hasIris,
        isEnrolled: isEnrolled,
        isEnabledByUser: isEnabled,
        boundUsername: boundUser,
      );
    } catch (e) {
      debugPrint('[BiometricService] getCapabilities error: $e');
      return const BiometricCapabilities();
    }
  }

  /// Perform native operating-system biometric authentication prompt.
  /// Never simulated: always delegates to the platform's native biometric prompt.
  Future<BiometricAuthResult> authenticate({
    String reason = 'Authenticate to access your CorpRegistry portal',
  }) async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        return BiometricAuthResult.failure(
          'Biometric hardware is not supported or available on this device.',
          'NotSupported',
        );
      }

      final canCheck = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();

      if (!canCheck || available.isEmpty) {
        return BiometricAuthResult.failure(
          'No biometrics are enrolled on this device. Please set up fingerprint or Face ID in device settings.',
          'NotEnrolled',
        );
      }

      // Invoke native OS biometric dialog
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );

      if (didAuthenticate) {
        return BiometricAuthResult.successful();
      } else {
        return BiometricAuthResult.cancelled();
      }
    } on PlatformException catch (e) {
      debugPrint(
        '[BiometricService] PlatformException: ${e.code} - ${e.message}',
      );
      final code = e.code.toLowerCase();

      if (code.contains('notenrolled') || code.contains('not_enrolled')) {
        return BiometricAuthResult.failure(
          'No biometrics enrolled. Please register your fingerprint or Face ID in device settings.',
          'NotEnrolled',
        );
      } else if (code.contains('lockedout') || code.contains('locked_out')) {
        return BiometricAuthResult.failure(
          'Biometrics temporarily locked due to failed attempts. Try again later or use password.',
          'LockedOut',
        );
      } else if (code.contains('permanentlylockedout') ||
          code.contains('permanently_locked_out')) {
        return BiometricAuthResult.failure(
          'Biometrics permanently locked. Please unlock your device using your screen lock passcode.',
          'PermanentlyLockedOut',
        );
      } else if (code.contains('passcodenotset') ||
          code.contains('passcode_not_set')) {
        return BiometricAuthResult.failure(
          'Device passcode is not set. Please enable screen lock in device security settings.',
          'PasscodeNotSet',
        );
      } else if (code.contains('notavailable') ||
          code.contains('not_available')) {
        return BiometricAuthResult.failure(
          'Biometric authentication is currently unavailable.',
          'NotAvailable',
        );
      } else if (code.contains('usercancel') ||
          code.contains('user_canceled') ||
          code.contains('cancel')) {
        return BiometricAuthResult.cancelled();
      } else {
        return BiometricAuthResult.failure(
          e.message ??
              'Biometric verification failed. Please try again or use your password.',
          e.code,
        );
      }
    } catch (e) {
      return BiometricAuthResult.failure(
        'An unexpected error occurred during biometric authentication: $e',
        'UnknownError',
      );
    }
  }

  /// Check if user has opted in to biometric login
  Future<bool> isBiometricLoginEnabled() async {
    try {
      final value = await _storage.read(key: _keyBiometricEnabled);
      return value == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Get the username bound to biometric authentication
  Future<String?> getBoundUsername() async {
    try {
      return await _storage.read(key: _keyBiometricUsername);
    } catch (_) {
      return null;
    }
  }

  /// Enable biometric login for a specific authenticated user after explicit consent
  Future<void> enableBiometricLogin(String username) async {
    try {
      await _storage.write(key: _keyBiometricEnabled, value: 'true');
      await _storage.write(key: _keyBiometricUsername, value: username.trim());
    } catch (e) {
      debugPrint('[BiometricService] Error enabling biometric login: $e');
    }
  }

  /// Disable biometric login
  Future<void> disableBiometricLogin() async {
    try {
      await _storage.delete(key: _keyBiometricEnabled);
      await _storage.delete(key: _keyBiometricUsername);
    } catch (e) {
      debugPrint('[BiometricService] Error disabling biometric login: $e');
    }
  }
}
