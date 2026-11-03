part of 'auth_bloc.dart';

abstract class AuthEvent {
  const AuthEvent();
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  final String? otpCode;

  const AuthLoginRequested({
    required this.email,
    required this.password,
    this.otpCode,
  });
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String name;
  final String? phoneNumber;

  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.name,
    this.phoneNumber,
  });
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthBiometricLoginRequested extends AuthEvent {
  const AuthBiometricLoginRequested();
}

class AuthPinLoginRequested extends AuthEvent {
  final String pin;

  const AuthPinLoginRequested({required this.pin});
}

class AuthForgotPasswordRequested extends AuthEvent {
  final String username;
  final String email;

  const AuthForgotPasswordRequested({
    required this.username,
    required this.email,
  });
}

class AuthResetPasswordRequested extends AuthEvent {
  final String token;
  final String newPassword;

  const AuthResetPasswordRequested({
    required this.token,
    required this.newPassword,
  });
}

class AuthChangePasswordRequested extends AuthEvent {
  final String currentPassword;
  final String newPassword;

  const AuthChangePasswordRequested({
    required this.currentPassword,
    required this.newPassword,
  });
}

class AuthCheckStatusRequested extends AuthEvent {
  const AuthCheckStatusRequested();
}

class AuthUserProfileUpdateRequested extends AuthEvent {
  final String? name;
  final String? phoneNumber;

  const AuthUserProfileUpdateRequested({
    this.name,
    this.phoneNumber,
  });
}

class AuthBiometricToggleRequested extends AuthEvent {
  final bool enable;

  const AuthBiometricToggleRequested({required this.enable});
}

class AuthPinSetRequested extends AuthEvent {
  final String pin;

  const AuthPinSetRequested({required this.pin});
}

class AuthPinChangeRequested extends AuthEvent {
  final String currentPin;
  final String newPin;

  const AuthPinChangeRequested({
    required this.currentPin,
    required this.newPin,
  });
}
