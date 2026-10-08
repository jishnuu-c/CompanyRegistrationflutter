class LoginRequest {
  final String usernameOrEmail;
  final String password;

  LoginRequest({
    required this.usernameOrEmail,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'usernameOrEmail': usernameOrEmail.trim(),
        'password': password,
      };
}

class AuthResponse {
  final String token;
  final String tokenType;
  final String username;
  final String email;
  final String fullName;
  final String role;
  final int? expiresIn;

  AuthResponse({
    required this.token,
    this.tokenType = 'Bearer',
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    this.expiresIn,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String? ?? '',
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      role: json['role'] as String? ?? 'ROLE_ADMIN',
      expiresIn: json['expiresIn'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'tokenType': tokenType,
        'username': username,
        'email': email,
        'fullName': fullName,
        'role': role,
        if (expiresIn != null) 'expiresIn': expiresIn,
      };

  UserProfile toUserProfile() => UserProfile(
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

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int?,
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
