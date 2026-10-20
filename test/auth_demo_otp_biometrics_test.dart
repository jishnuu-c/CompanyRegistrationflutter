import 'package:flutter_test/flutter_test.dart';
import 'package:company_reg_flutter/models/auth_model.dart';
import 'package:company_reg_flutter/services/auth/auth_config.dart';
import 'package:company_reg_flutter/services/auth/demo_auth_provider.dart';
import 'package:company_reg_flutter/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppAuthConfig Mode Selection Tests', () {
    test('Default mode is DEMO mode', () {
      final config = AppAuthConfig();
      expect(config.isDemoMode, isTrue);
      expect(config.mode, equals(AuthMode.demo));
    });

    test('Can switch mode between DEMO and API', () async {
      final config = AppAuthConfig();
      await config.setMode(AuthMode.api);
      expect(config.isApiMode, isTrue);

      await config.setMode(AuthMode.demo);
      expect(config.isDemoMode, isTrue);
    });
  });

  group('DemoAuthProvider Password Authentication', () {
    late DemoAuthProvider provider;

    setUp(() {
      provider = DemoAuthProvider();
    });

    test('SuperAdmin default credentials succeed in DEMO mode', () async {
      final response = await provider.loginWithPassword(
        usernameOrEmail: 'SuperAdmin',
        password: 'companyAdmin',
      );

      expect(response.username, equals('SuperAdmin'));
      expect(response.isDemoSession, isTrue);
      expect(response.token, startsWith('DEMO_SESSION_'));
      expect(provider.isTokenExpired(response.token), isFalse);
    });

    test('Invalid credentials throw descriptive Exception', () async {
      expect(
        () => provider.loginWithPassword(
          usernameOrEmail: 'SuperAdmin',
          password: 'wrongPassword123',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Register creates demo account successfully', () async {
      final req = RegisterRequest(
        fullName: 'Test User',
        username: 'test_user_${DateTime.now().millisecondsSinceEpoch}',
        email: 'test_${DateTime.now().millisecondsSinceEpoch}@example.com',
        password: 'testPassword123',
      );

      final response = await provider.register(req);
      expect(response.isDemoSession, isTrue);
      expect(response.username, equals(req.username));
    });
  });

  group('DemoAuthProvider OTP Flow Tests', () {
    late DemoAuthProvider provider;

    setUp(() {
      provider = DemoAuthProvider();
    });

    test('Request OTP generates 6-digit code with cooldown', () async {
      const identifier = '9876543210';
      final result = await provider.requestOtp(identifier: identifier);

      expect(result.success, isTrue);
      expect(result.isSimulated, isTrue);
      expect(result.expiresInSeconds, equals(120));
      expect(result.cooldownSeconds, equals(30));

      // In test/debug mode, debugOtpCode is available for automated validation
      expect(result.debugOtpCode, isNotNull);
      expect(result.debugOtpCode!.length, equals(6));
      expect(int.tryParse(result.debugOtpCode!), isNotNull);
    });

    test(
      'Resend OTP within cooldown period throws rate-limiting Exception',
      () async {
        const identifier = '9998887776';
        await provider.requestOtp(identifier: identifier);

        // Immediate second request must trigger cooldown restriction
        expect(
          () => provider.requestOtp(identifier: identifier),
          throwsA(predicate((e) => e.toString().contains('Please wait'))),
        );
      },
    );

    test('Valid OTP verification creates demo session', () async {
      const identifier = '9123456780';
      final otpResult = await provider.requestOtp(identifier: identifier);
      final code = otpResult.debugOtpCode!;

      final authResponse = await provider.verifyOtp(
        identifier: identifier,
        otp: code,
      );

      expect(authResponse.isDemoSession, isTrue);
      expect(authResponse.token, startsWith('DEMO_SESSION_'));
    });

    test(
      'Invalid OTP decrements remaining attempts and throws error',
      () async {
        const identifier = '9123456789';
        await provider.requestOtp(identifier: identifier);

        expect(
          () => provider.verifyOtp(identifier: identifier, otp: '000000'),
          throwsA(predicate((e) => e.toString().contains('remaining'))),
        );
      },
    );

    test('3 failed attempts lock/invalidate the OTP', () async {
      const identifier = '9555444333';
      await provider.requestOtp(identifier: identifier);

      // Attempt 1
      try {
        await provider.verifyOtp(identifier: identifier, otp: '111111');
      } catch (_) {}

      // Attempt 2
      try {
        await provider.verifyOtp(identifier: identifier, otp: '222222');
      } catch (_) {}

      // Attempt 3: Locks out
      expect(
        () => provider.verifyOtp(identifier: identifier, otp: '333333'),
        throwsA(
          predicate((e) => e.toString().contains('Maximum attempts exceeded')),
        ),
      );
    });
  });

  group('AuthService State & Facade Tests', () {
    test('AuthService initializes in DEMO mode by default', () {
      final auth = AuthService();
      expect(auth.isDemoMode, isTrue);
      expect(auth.isLoggedIn, isFalse);
    });

    test('AuthService login updates session and notifies listeners', () async {
      final auth = AuthService();
      await auth.setAuthMode(AuthMode.demo);

      final response = await auth.login('SuperAdmin', 'companyAdmin');
      expect(auth.isLoggedIn, isTrue);
      expect(auth.isDemoSession, isTrue);
      expect(auth.currentUser?.username, equals('SuperAdmin'));
      expect(response.token, startsWith('DEMO_SESSION_'));

      // Logout clears session
      auth.logout();
      expect(auth.isLoggedIn, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('AuthService getAuthHeaders handles Demo vs Api headers safely', () {
      final auth = AuthService();
      final demoHeaders = auth.getAuthHeaders({'Custom': 'Header'});
      expect(demoHeaders['Accept'], equals('application/json'));
      expect(demoHeaders['Custom'], equals('Header'));
    });
  });

  group('BiometricCapabilities Model Tests', () {
    test('BiometricCapabilities reports correct display names', () {
      const faceOnly = BiometricCapabilities(
        isSupported: true,
        canCheckBiometrics: true,
        hasFace: true,
        hasFingerprint: false,
        isEnrolled: true,
      );
      expect(faceOnly.displayName, equals('Face ID'));
      expect(faceOnly.canAuthenticate, isTrue);

      const fingerOnly = BiometricCapabilities(
        isSupported: true,
        canCheckBiometrics: true,
        hasFace: false,
        hasFingerprint: true,
        isEnrolled: true,
      );
      expect(fingerOnly.displayName, equals('Fingerprint'));

      const both = BiometricCapabilities(
        isSupported: true,
        canCheckBiometrics: true,
        hasFace: true,
        hasFingerprint: true,
        isEnrolled: true,
      );
      expect(both.displayName, equals('Biometrics (Face/Fingerprint)'));
    });
  });
}
