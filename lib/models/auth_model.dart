class LoginRequest {
  final String usernameOrEmail;
  final String password;

  LoginRequest({required this.usernameOrEmail, required this.password});

  Map<String, dynamic> toJson() => {
    'usernameOrEmail': usernameOrEmail.trim(),
    'password': password,
  };
}

class RegisterRequest {
  final String fullName;
  final String username;
  final String email;
  final String password;

  RegisterRequest({
    required this.fullName,
    required this.username,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName.trim(),
    'username': username.trim(),
    'email': email.trim(),
    'password': password,
  };
}

class AuthResponse {
  final int? id;
  final String token;
  final String tokenType;
  final String username;
  final String email;
  final String fullName;
  final String role;
  final int? expiresIn;

  final bool isDemoSession;

  AuthResponse({
    this.id,
    required this.token,
    this.tokenType = 'Bearer',
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    this.expiresIn,
    this.isDemoSession = false,
  });

  bool get isSuperAdmin =>
      role == 'SUPER_ADMIN' || role == 'ROLE_SUPER_ADMIN';
  bool get isCompanyUser =>
      role == 'COMPANY_USER' || role == 'ROLE_COMPANY_USER';

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? ''),
      token: json['token'] as String? ?? '',
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      role: json['role'] as String? ?? 'ROLE_ADMIN',
      expiresIn: json['expiresIn'] as int?,
      isDemoSession: json['isDemoSession'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'token': token,
    'tokenType': tokenType,
    'username': username,
    'email': email,
    'fullName': fullName,
    'role': role,
    if (expiresIn != null) 'expiresIn': expiresIn,
    'isDemoSession': isDemoSession,
  };

  UserProfile toUserProfile() => UserProfile(
    id: id,
    username: username,
    email: email,
    fullName: fullName,
    role: role,
  );
}

class UserProfile {
  final int? id;
  final String username;
  final String email;
  final String fullName;
  final String role;

  UserProfile({
    this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
  });

  bool get isSuperAdmin =>
      role == 'SUPER_ADMIN' || role == 'ROLE_SUPER_ADMIN';
  bool get isCompanyUser =>
      role == 'COMPANY_USER' || role == 'ROLE_COMPANY_USER';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? ''),
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      role: json['role'] as String? ?? 'ROLE_ADMIN',
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'username': username,
    'email': email,
    'fullName': fullName,
    'role': role,
  };
}

/// Result returned after requesting an OTP
class OtpRequestResult {
  final bool success;
  final String message;
  final int expiresInSeconds;
  final int cooldownSeconds;
  final String? debugOtpCode; // Populated ONLY in demo mode during debug builds
  final bool isSimulated;

  const OtpRequestResult({
    required this.success,
    required this.message,
    this.expiresInSeconds = 120,
    this.cooldownSeconds = 30,
    this.debugOtpCode,
    this.isSimulated = false,
  });
}

/// Capabilities and enrollment state for biometric authentication on device
class BiometricCapabilities {
  final bool isSupported;
  final bool canCheckBiometrics;
  final bool hasFingerprint;
  final bool hasFace;
  final bool hasIris;
  final bool isEnrolled;
  final bool isEnabledByUser;
  final String? boundUsername;
  final String? configuredBiometricType;

  const BiometricCapabilities({
    this.isSupported = false,
    this.canCheckBiometrics = false,
    this.hasFingerprint = false,
    this.hasFace = false,
    this.hasIris = false,
    this.isEnrolled = false,
    this.isEnabledByUser = false,
    this.boundUsername,
    this.configuredBiometricType,
  });

  bool get canAuthenticate => isSupported && canCheckBiometrics && isEnrolled;

  bool get isFaceOnly {
    if (configuredBiometricType == 'face') return true;
    if (configuredBiometricType == 'fingerprint') return false;
    return hasFace && !hasFingerprint;
  }

  bool get isFingerprintOnly {
    if (configuredBiometricType == 'fingerprint') return true;
    if (configuredBiometricType == 'face') return false;
    return hasFingerprint && !hasFace;
  }

  String get displayName {
    if (isFaceOnly) return 'Face ID';
    if (isFingerprintOnly) return 'Fingerprint';
    if (hasFace && hasFingerprint) return 'Biometrics (Face/Fingerprint)';
    if (hasIris) return 'Iris Scan';
    return 'Biometrics';
  }

  String get quickAccessLabel {
    if (isFaceOnly) return 'Sign In with Face ID';
    if (isFingerprintOnly) return 'Sign In with Fingerprint';
    return 'Sign In with Biometrics';
  }

  String get successMessage {
    if (isFaceOnly) return 'Face ID login successful';
    if (isFingerprintOnly) return 'Fingerprint login successful';
    return 'Biometric login successful';
  }
}
