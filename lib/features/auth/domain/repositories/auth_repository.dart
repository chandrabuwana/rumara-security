import '../usecases/login_use_case.dart';

abstract class AuthRepository {
  Future<LoginResult> login({
    required String username,
    required String password,
    String? otpCode,
  });

  Future<RegisterResult> register({
    required String email,
    required String password,
    required String name,
    String? phoneNumber,
  });

  Future<LogoutResult> logout();

  Future<TokenResult> refreshToken();

  Future<UserResult> getCurrentUser();

  Future<PasswordResult> forgotPassword(String email);

  Future<PasswordResult> resetPassword({
    required String token,
    required String newPassword,
  });

  Future<PasswordResult> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<EmailResult> verifyEmail(String token);

  Future<EmailResult> resendEmailVerification();

  Future<BiometricResult> loginWithBiometric();

  Future<BiometricResult> enableBiometric();

  Future<BiometricResult> disableBiometric();

  Future<PinResult> loginWithPin(String pin);

  Future<PinResult> setPin(String pin);

  Future<PinResult> changePin({
    required String currentPin,
    required String newPin,
  });

  Future<ProfileResult> updateProfile({
    String? name,
    String? phoneNumber,
  });

  Future<bool> isLoggedIn();

  Future<bool> hasValidToken();
}

// Result types
class RegisterResult {
  final bool isSuccess;
  final AuthToken? token;
  final User? user;
  final Failure? failure;

  const RegisterResult({
    required this.isSuccess,
    this.token,
    this.user,
    this.failure,
  });

  factory RegisterResult.success({AuthToken? token, User? user}) {
    return RegisterResult(isSuccess: true, token: token, user: user);
  }

  factory RegisterResult.failure(Failure failure) {
    return RegisterResult(isSuccess: false, failure: failure);
  }
}

class LogoutResult {
  final bool isSuccess;
  final Failure? failure;

  const LogoutResult({required this.isSuccess, this.failure});

  factory LogoutResult.success() {
    return const LogoutResult(isSuccess: true);
  }

  factory LogoutResult.failure(Failure failure) {
    return LogoutResult(isSuccess: false, failure: failure);
  }
}

class TokenResult {
  final bool isSuccess;
  final AuthToken? token;
  final Failure? failure;

  const TokenResult({required this.isSuccess, this.token, this.failure});

  factory TokenResult.success(AuthToken token) {
    return TokenResult(isSuccess: true, token: token);
  }

  factory TokenResult.failure(Failure failure) {
    return TokenResult(isSuccess: false, failure: failure);
  }
}

class UserResult {
  final bool isSuccess;
  final User? user;
  final Failure? failure;

  const UserResult({required this.isSuccess, this.user, this.failure});

  factory UserResult.success(User user) {
    return UserResult(isSuccess: true, user: user);
  }

  factory UserResult.failure(Failure failure) {
    return UserResult(isSuccess: false, failure: failure);
  }
}

class PasswordResult {
  final bool isSuccess;
  final Failure? failure;

  const PasswordResult({required this.isSuccess, this.failure});

  factory PasswordResult.success() {
    return const PasswordResult(isSuccess: true);
  }

  factory PasswordResult.failure(Failure failure) {
    return PasswordResult(isSuccess: false, failure: failure);
  }
}

class EmailResult {
  final bool isSuccess;
  final Failure? failure;

  const EmailResult({required this.isSuccess, this.failure});

  factory EmailResult.success() {
    return const EmailResult(isSuccess: true);
  }

  factory EmailResult.failure(Failure failure) {
    return EmailResult(isSuccess: false, failure: failure);
  }
}

class BiometricResult {
  final bool isSuccess;
  final bool? authenticated;
  final Failure? failure;

  const BiometricResult(
      {required this.isSuccess, this.authenticated, this.failure});

  factory BiometricResult.success({bool authenticated = true}) {
    return BiometricResult(isSuccess: true, authenticated: authenticated);
  }

  factory BiometricResult.failure(Failure failure) {
    return BiometricResult(isSuccess: false, failure: failure);
  }
}

class PinResult {
  final bool isSuccess;
  final bool? authenticated;
  final Failure? failure;

  const PinResult({required this.isSuccess, this.authenticated, this.failure});

  factory PinResult.success({bool authenticated = true}) {
    return PinResult(isSuccess: true, authenticated: authenticated);
  }

  factory PinResult.failure(Failure failure) {
    return PinResult(isSuccess: false, failure: failure);
  }
}

class ProfileResult {
  final bool isSuccess;
  final User? user;
  final Failure? failure;

  const ProfileResult({required this.isSuccess, this.user, this.failure});

  factory ProfileResult.success(User user) {
    return ProfileResult(isSuccess: true, user: user);
  }

  factory ProfileResult.failure(Failure failure) {
    return ProfileResult(isSuccess: false, failure: failure);
  }
}

// User entity
class User {
  final String id;
  final String email;
  final String name;
  final String? phoneNumber;
  final String? profileImageUrl;
  final bool isEmailVerified;
  final bool isBiometricEnabled;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.phoneNumber,
    this.profileImageUrl,
    required this.isEmailVerified,
    required this.isBiometricEnabled,
    required this.createdAt,
    this.lastLoginAt,
  });
}
