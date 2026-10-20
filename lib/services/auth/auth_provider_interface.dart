import '../../models/auth_model.dart';
import 'auth_config.dart';

/// Contract defining all authentication operations for both Demo and API providers.
/// Enables seamless switching between simulated local testing and production Spring Boot backend.
abstract class AuthProvider {
  /// The operational mode represented by this provider
  AuthMode get mode;

  /// Authenticate using username or email and password
  Future<AuthResponse> loginWithPassword({
    required String usernameOrEmail,
    required String password,
  });

  /// Register a new account
  Future<AuthResponse> register(RegisterRequest request);

  /// Request a 6-digit OTP sent to the given identifier (phone or email)
  Future<OtpRequestResult> requestOtp({required String identifier});

  /// Verify the 6-digit OTP code against the identifier
  Future<AuthResponse> verifyOtp({
    required String identifier,
    required String otp,
  });

  /// Fetch user profile details for an active session
  Future<UserProfile?> fetchCurrentUser(String? token);

  /// Refresh existing session if supported by provider
  Future<AuthResponse?> refreshSession(String? token);

  /// End user session and clear provider-specific session data
  Future<void> logout();

  /// Determine if token is expired
  bool isTokenExpired(String? token);

  /// Build HTTP headers injected with Authorization header if session is valid
  Map<String, String> getAuthHeaders(
    String? token, [
    Map<String, String>? baseHeaders,
  ]);

  /// Authenticate device-bound biometric credentials for the designated user
  Future<AuthResponse> authenticateWithBiometrics({required String username});

  /// Securely register biometric access for a user after explicit initial authentication
  Future<void> registerBiometricCredential({
    required String username,
    required String sessionToken,
  });

  /// Revoke device biometric binding
  Future<void> revokeBiometricCredential();
}
