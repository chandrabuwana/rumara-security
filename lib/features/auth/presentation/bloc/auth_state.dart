part of 'auth_bloc.dart';

enum AuthStatus {
  initial,
  loading,
  passwordResetLinkSent,
  changePasswordSuccess,
  deviceVerification,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  final bool isLoading;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.isLoading = false,
  });

  factory AuthState.initial() {
    return const AuthState(
      status: AuthStatus.initial,
      isLoading: false,
    );
  }

  factory AuthState.loading() {
    return const AuthState(
      status: AuthStatus.loading,
      isLoading: true,
    );
  }

  factory AuthState.authenticated(User user) {
    return AuthState(
      status: AuthStatus.authenticated,
      user: user,
      isLoading: false,
    );
  }

  factory AuthState.unauthenticated() {
    return const AuthState(
      status: AuthStatus.unauthenticated,
      isLoading: false,
    );
  }

  factory AuthState.deviceVerification(String message) {
    return AuthState(
      status: AuthStatus.deviceVerification,
      errorMessage: message,
      isLoading: false,
    );
  }

  factory AuthState.error(String message) {
    return AuthState(
      status: AuthStatus.error,
      errorMessage: message,
      isLoading: false,
    );
  }

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthState &&
        other.status == status &&
        other.user == user &&
        other.errorMessage == errorMessage &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode {
    return Object.hash(status, user, errorMessage, isLoading);
  }

  @override
  String toString() {
    return 'AuthState(status: $status, user: $user, errorMessage: $errorMessage, isLoading: $isLoading)';
  }
}

// Temporary User class
class User {
  final String id;
  final String email;
  final String name;
  final String? phoneNumber;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.phoneNumber,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.email == email &&
        other.name == name &&
        other.phoneNumber == phoneNumber;
  }

  @override
  int get hashCode {
    return Object.hash(id, email, name, phoneNumber);
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, name: $name, phoneNumber: $phoneNumber)';
  }
}
