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
  static const MethodChannel _detectChannel = MethodChannel(
    'com.example.company_reg_flutter/biometric_detect',
  );

  static const String _keyBiometricEnabled = 'biometric_auth_enabled';
  static const String _keyBiometricUsername = 'biometric_bound_username';
  static const String _keyBiometricType = 'biometric_bound_type';

  BiometricService._internal();

  /// Check hardware support and enrollment state on the physical/simulated device
  Future<BiometricCapabilities> getCapabilities() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();

      final explicitFingerprint = available.contains(BiometricType.fingerprint);
      final explicitFace = available.contains(BiometricType.face);
      final explicitIris = available.contains(BiometricType.iris);
      final hasGenericBiometric =
          available.contains(BiometricType.strong) ||
          available.contains(BiometricType.weak);

      bool hasFingerprint = explicitFingerprint;
      bool hasFace = explicitFace;
      bool hasIris = explicitIris;

      // On Android, check actual physical hardware presence and enrolled status
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final res = await _detectChannel.invokeMapMethod<String, dynamic>(
            'getBiometricHardwareInfo',
          );
          if (res != null) {
            final hasFpFeature = res['hasFingerprintFeature'] == true;
            final isFpHwDetected = res['isFingerprintHardwareDetected'] == true;
            final hasEnrolledFp = res['hasEnrolledFingerprints'] == true;
            final hasFaceFeature = res['hasFaceFeature'] == true;

            // If device has no fingerprint hardware or no enrolled fingerprints,
            // never classify it as fingerprint
            if (!hasFpFeature || !isFpHwDetected || !hasEnrolledFp) {
              hasFingerprint = false;
            } else if (explicitFingerprint || hasGenericBiometric) {
              hasFingerprint = true;
            }

            if (hasFaceFeature) {
              hasFace = true;
            }
          }
        } catch (e) {
          debugPrint('[BiometricService] Hardware info query error: $e');
        }
      }

      // If generic biometrics (e.g. Android 2D Face Unlock) are available,
      // but fingerprint is not present or not enrolled, it is face authentication
      if (hasGenericBiometric && !hasFingerprint && !hasIris) {
        hasFace = true;
      }

      // If available biometrics exist on device, but neither fingerprint nor face was explicitly set
      if (available.isNotEmpty && !hasFingerprint && !hasFace && !hasIris) {
        hasFace = true;
      }

      final isEnrolled = available.isNotEmpty;
      final isEnabled = await isBiometricLoginEnabled();
      final boundUser = isEnabled ? await getBoundUsername() : null;
      final savedType = isEnabled ? await getBoundBiometricType() : null;

      // Determine configured biometric type (either from saved enrollment or detected hardware)
      String? configuredType = savedType;
      if (configuredType == null && (hasFace || hasFingerprint)) {
        if (hasFace && !hasFingerprint) {
          configuredType = 'face';
        } else if (hasFingerprint && !hasFace) {
          configuredType = 'fingerprint';
        }
      }

      return BiometricCapabilities(
        isSupported: isSupported,
        canCheckBiometrics: canCheck,
        hasFingerprint: hasFingerprint,
        hasFace: hasFace,
        hasIris: hasIris,
        isEnrolled: isEnrolled,
        isEnabledByUser: isEnabled && boundUser != null && boundUser.isNotEmpty,
        boundUsername: boundUser,
        configuredBiometricType: configuredType,
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
          'No biometrics are enrolled on this device. Please set up Face ID or fingerprint in device settings.',
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
          'No biometrics enrolled. Please register your Face ID or fingerprint in device settings.',
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

  /// Check if user has opted in to biometric login and has a valid bound username.
  /// Automatically repairs inconsistent states if found.
  Future<bool> isBiometricLoginEnabled() async {
    try {
      final enabledValue = await _storage.read(key: _keyBiometricEnabled);
      if (enabledValue != 'true') {
        return false;
      }
      final boundUser = await _storage.read(key: _keyBiometricUsername);
      if (boundUser == null || boundUser.trim().isEmpty) {
        // Inconsistent partial state: flag is true but username is missing.
        // Clean up partial enrollment to maintain consistency.
        await disableBiometricLogin();
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[BiometricService] Error checking biometric status: $e');
      return false;
    }
  }

  /// Get the username bound to biometric authentication.
  /// Returns null if biometric login is not enabled or bound username is empty.
  Future<String?> getBoundUsername() async {
    try {
      final enabledValue = await _storage.read(key: _keyBiometricEnabled);
      if (enabledValue != 'true') {
        return null;
      }
      final username = await _storage.read(key: _keyBiometricUsername);
      if (username == null || username.trim().isEmpty) {
        return null;
      }
      return username.trim();
    } catch (e) {
      debugPrint('[BiometricService] Error retrieving bound username: $e');
      return null;
    }
  }

  /// Get the saved configured biometric type ('face' or 'fingerprint')
  Future<String?> getBoundBiometricType() async {
    try {
      final enabledValue = await _storage.read(key: _keyBiometricEnabled);
      if (enabledValue != 'true') {
        return null;
      }
      return await _storage.read(key: _keyBiometricType);
    } catch (e) {
      debugPrint('[BiometricService] Error retrieving biometric type: $e');
      return null;
    }
  }

  /// Enable biometric login for a specific authenticated user after explicit consent.
  /// Atomic: writes username, biometric type, and enabled flag. If any write fails,
  /// rolls back all keys and throws a descriptive exception.
  Future<void> enableBiometricLogin(
    String username, {
    String? biometricType,
  }) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) {
      throw ArgumentError(
        'Username cannot be empty when enabling biometric login.',
      );
    }

    try {
      // 1. Write the bound username first
      await _storage.write(key: _keyBiometricUsername, value: cleanUsername);
      // 2. Write the detected/configured biometric type if provided
      if (biometricType != null && biometricType.trim().isNotEmpty) {
        await _storage.write(
          key: _keyBiometricType,
          value: biometricType.trim(),
        );
      }
      // 3. Write the enabled flag
      await _storage.write(key: _keyBiometricEnabled, value: 'true');
    } catch (e) {
      // Rollback all keys on failure to prevent partial enrollment state
      try {
        await _storage.delete(key: _keyBiometricEnabled);
        await _storage.delete(key: _keyBiometricUsername);
        await _storage.delete(key: _keyBiometricType);
      } catch (_) {}
      debugPrint('[BiometricService] Failed to enable biometric login: $e');
      throw Exception('Failed to securely save biometric enrollment: $e');
    }
  }

  /// Disable biometric login and remove all bound credentials
  Future<void> disableBiometricLogin() async {
    try {
      await _storage.delete(key: _keyBiometricEnabled);
      await _storage.delete(key: _keyBiometricUsername);
      await _storage.delete(key: _keyBiometricType);
    } catch (e) {
      debugPrint('[BiometricService] Error disabling biometric login: $e');
    }
  }
}
