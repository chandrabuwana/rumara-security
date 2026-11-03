import 'package:injectable/injectable.dart';

// Error classes
abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class AuthenticationFailure extends Failure {
  const AuthenticationFailure(super.message);
}

class DeviceVerificationFailure extends Failure {
  const DeviceVerificationFailure(super.message);
}

// Validators
class Validators {
  static String? validateNrp(String? nrp) {
    if (nrp == null || nrp.isEmpty) {
      return 'NRP tidak boleh kosong';
    }
    if (nrp.length < 3) {
      return 'NRP minimal 3 karakter';
    }
    return null;
  }

  static String? validateUsername(String? username) {
    if (username == null || username.isEmpty) {
      return 'Username tidak boleh kosong';
    }
    if (username.length < 3) {
      return 'Username minimal 3 karakter';
    }
    return null;
  }

  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password tidak boleh kosong';
    }
    if (password.length < 3) {
      return 'Password minimal 3 karakter';
    }
    return null;
  }

  static String? validateName(String? name) {
    if (name == null || name.isEmpty) {
      return 'Nama tidak boleh kosong';
    }
    if (name.length < 2) {
      return 'Nama minimal 2 karakter';
    }
    return null;
  }

  static String? validatePhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) {
      return 'Nomor telepon tidak boleh kosong';
    }
    if (!RegExp(r'^(\+62|62|0)[0-9]{9,12}$').hasMatch(phone)) {
      return 'Format nomor telepon tidak valid';
    }
    return null;
  }

  static String? validatePin(String? pin) {
    if (pin == null || pin.isEmpty) {
      return 'PIN tidak boleh kosong';
    }
    if (pin.length != 6) {
      return 'PIN harus 6 digit';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(pin)) {
      return 'PIN hanya boleh berisi angka';
    }
    return null;
  }
}

// Auth Token
class AuthToken {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final DateTime issuedAt;

  const AuthToken({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'Bearer',
    required this.expiresIn,
    required this.issuedAt,
  });
}

// Login Repository Interface - Specific for LoginUseCase
abstract class LoginRepository {
  Future<LoginResult> login({
    required String username,
    required String password,
    String? otpCode,
  });

  Future<({bool ok, String message})> requestDeviceOtp({
    required String username,
    required String password,
  });
}

// Login Use Case
@injectable
class LoginUseCase {
  final LoginRepository repository;

  const LoginUseCase(this.repository);

  Future<LoginResult> call({
    required String username,
    required String password,
    String? otpCode,
  }) async {
    try {
      // Validate input - NRP adalah free text, tidak perlu validasi email
      final usernameValidation = Validators.validateUsername(username);
      if (usernameValidation != null) {
        return LoginResult.failure(ValidationFailure(usernameValidation));
      }

      final passwordValidation = Validators.validatePassword(password);
      if (passwordValidation != null) {
        return LoginResult.failure(ValidationFailure(passwordValidation));
      }

      // Perform login
      final result = await repository.login(
        username: username.trim(),
        password: password,
        otpCode: otpCode,
      );

      return result;
    } catch (e) {
      return LoginResult.failure(
          ServerFailure('Login failed: ${e.toString()}'));
    }
  }
}

// User data from login
class LoginUser {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final List<String> roleIds;
  final List<String> roleNames;

  const LoginUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.roleIds,
    required this.roleNames,
  });
}

// Login Result
class LoginResult {
  final AuthToken? token;
  final LoginUser? user;
  final Failure? failure;
  final bool isSuccess;

  const LoginResult._({
    this.token,
    this.user,
    this.failure,
    required this.isSuccess,
  });

  factory LoginResult.success(AuthToken token, LoginUser user) {
    return LoginResult._(
      token: token,
      user: user,
      isSuccess: true,
    );
  }

  factory LoginResult.failure(Failure failure) {
    return LoginResult._(
      failure: failure,
      isSuccess: false,
    );
  }
}
