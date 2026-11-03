import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/utils/validators.dart' as validator;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/security/security_manager.dart';
import '../../domain/usecases/login_use_case.dart';
import '../../data/datasources/auth_remote_data_source.dart';

part 'auth_event.dart';
part 'auth_state.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final AuthRemoteDataSource authRemoteDataSource;

  AuthBloc(this.loginUseCase, this.authRemoteDataSource) : super(AuthState.initial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthBiometricLoginRequested>(_onBiometricLoginRequested);
    on<AuthPinLoginRequested>(_onPinLoginRequested);
    on<AuthForgotPasswordRequested>(_onForgotPasswordRequested);
    on<AuthResetPasswordRequested>(_onResetPasswordRequested);
    on<AuthChangePasswordRequested>(_onChangePasswordRequested);
    on<AuthCheckStatusRequested>(_onCheckStatusRequested);
    on<AuthUserProfileUpdateRequested>(_onUserProfileUpdateRequested);
    on<AuthBiometricToggleRequested>(_onBiometricToggleRequested);
    on<AuthPinSetRequested>(_onPinSetRequested);
    on<AuthPinChangeRequested>(_onPinChangeRequested);
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      // Call login use case dengan username (NRP)
      final result = await loginUseCase(
        username: event.email, // event.email sebenarnya berisi NRP
        password: event.password,
        otpCode: event.otpCode,
      );

      if (result.failure is DeviceVerificationFailure) {
        emit(AuthState.deviceVerification(result.failure!.message));
        return;
      }

      if (result.isSuccess && result.token != null && result.user != null) {
        // Login berhasil, token dan user data sudah tersimpan di secure storage
        // Buat user object dari LoginUser
        final loginUser = result.user!;
        final user = User(
          id: loginUser.id,
          email: loginUser.email,
          name: loginUser.fullName,
          phoneNumber: null,
        );

        print('');
        print('✅ ========================================');
        print('✅ AUTH BLOC - LOGIN SUCCESS');
        print('✅ ========================================');
        print('✅ User ID: ${user.id}');
        print('✅ User Name: ${user.name}');
        print('✅ User Email: ${user.email}');
        print('✅ ========================================');
        print('');

        // Note: Employee locations are now fetched in the location tracking page
        // No need to fetch them during login

        print('✅ ========================================');
        print('✅ AUTH BLOC - EMITTING AUTHENTICATED STATE');
        print('✅ ========================================');
        print('✅ About to emit AuthState.authenticated...');
        emit(AuthState.authenticated(user));
        print('✅ Authenticated state emitted!');
        print('✅ ========================================');
        print('');
      } else {
        // Login gagal
        final errorMessage = result.failure?.message ?? 'Login gagal';

        // Emit error state dengan message
        emit(AuthState.error(errorMessage));
      }
    } catch (e) {
      emit(AuthState.error('Terjadi kesalahan: ${e.toString()}'));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      // Validate inputs
      final emailValidation = validator.Validators.validateEmail(event.email);
      if (emailValidation != null) {
        emit(AuthState.error(emailValidation));
        return;
      }

      final passwordValidation =
          validator.Validators.validatePassword(event.password);
      if (passwordValidation != null) {
        emit(AuthState.error(passwordValidation));
        return;
      }

      final nameValidation = validator.Validators.validateName(event.name);
      if (nameValidation != null) {
        emit(AuthState.error(nameValidation));
        return;
      }

      if (event.phoneNumber != null) {
        final phoneValidation =
            validator.Validators.validatePhoneNumber(event.phoneNumber);
        if (phoneValidation != null) {
          emit(AuthState.error(phoneValidation));
          return;
        }
      }

      // Mock successful registration
      await Future.delayed(const Duration(seconds: 1));

      final user = User(
        id: '1',
        email: event.email.trim().toLowerCase(),
        name: event.name.trim(),
        phoneNumber: event.phoneNumber?.trim(),
      );

      emit(AuthState.authenticated(user));
    } catch (e) {
      emit(AuthState.error('Registration failed: ${e.toString()}'));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      emit(AuthState.unauthenticated());
    } catch (e) {
      emit(AuthState.error('Logout failed: ${e.toString()}'));
    }
  }

  Future<void> _onBiometricLoginRequested(
    AuthBiometricLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      // Mock biometric login
      await Future.delayed(const Duration(seconds: 1));

      final user = User(
        id: '1',
        email: 'demo@example.com',
        name: 'Demo User',
        phoneNumber: null,
      );

      emit(AuthState.authenticated(user));
    } catch (e) {
      emit(AuthState.error('Biometric login failed: ${e.toString()}'));
    }
  }

  Future<void> _onPinLoginRequested(
    AuthPinLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      final pinValidation = validator.Validators.validatePin(event.pin);
      if (pinValidation != null) {
        emit(AuthState.error(pinValidation));
        return;
      }

      // Mock PIN login
      await Future.delayed(const Duration(seconds: 1));

      final user = User(
        id: '1',
        email: 'demo@example.com',
        name: 'Demo User',
        phoneNumber: null,
      );

      emit(AuthState.authenticated(user));
    } catch (e) {
      emit(AuthState.error('PIN login failed: ${e.toString()}'));
    }
  }

  Future<void> _onForgotPasswordRequested(
    AuthForgotPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      if (event.username.trim().isEmpty) {
        emit(AuthState.error('NRP tidak boleh kosong'));
        return;
      }

      final emailValidation = validator.Validators.validateEmail(event.email);
      if (emailValidation != null) {
        emit(AuthState.error(emailValidation));
        return;
      }

      final response = await authRemoteDataSource.resetPassword({
        'Username': event.username.trim(),
        'Email': event.email.trim(),
      });

      final succeeded = response.succeeded == true;
      final message = response.message?.trim();
      final description = response.description?.trim();
      final errorMessage =
          (message != null && message.isNotEmpty) ? message : (description ?? 'Reset password gagal');

      if (!succeeded) {
        emit(AuthState.error(errorMessage));
        return;
      }

      emit(state.copyWith(
        status: AuthStatus.passwordResetLinkSent,
        isLoading: false,
        errorMessage: null,
      ));
    } catch (e) {
      emit(AuthState.error('Reset password gagal: ${e.toString()}'));
    }
  }

  Future<void> _onResetPasswordRequested(
    AuthResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      final passwordValidation =
          validator.Validators.validatePassword(event.newPassword);
      if (passwordValidation != null) {
        emit(AuthState.error(passwordValidation));
        return;
      }

      // Mock reset password
      await Future.delayed(const Duration(seconds: 1));
      emit(AuthState.unauthenticated());
    } catch (e) {
      emit(AuthState.error('Failed to reset password: ${e.toString()}'));
    }
  }

  Future<void> _onChangePasswordRequested(
    AuthChangePasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      if (event.currentPassword.trim().isEmpty) {
        emit(AuthState.error('Password saat ini tidak boleh kosong'));
        return;
      }

      if (event.newPassword.trim().isEmpty) {
        emit(AuthState.error('Password baru tidak boleh kosong'));
        return;
      }

      if (event.currentPassword == event.newPassword) {
        emit(AuthState.error(
            'New password must be different from current password'));
        return;
      }

      final userId = await SecurityManager.readSecurely(AppConstants.userIdKey);
      if (userId == null || userId.trim().isEmpty) {
        emit(AuthState.error('User tidak ditemukan. Silakan login ulang.'));
        return;
      }

      final response = await authRemoteDataSource.changePassword(
        {
          'UserId': userId,
          'NewPassword': event.newPassword.trim(),
          'Password': event.currentPassword.trim(),
        },
      );

      final succeeded = response.succeeded == true;
      final message = response.message?.trim();
      final description = response.description?.trim();
      final errorMessage =
          (message != null && message.isNotEmpty) ? message : (description ?? 'Ubah password gagal');

      if (!succeeded) {
        emit(AuthState.error(errorMessage));
        return;
      }

      emit(state.copyWith(
        status: AuthStatus.changePasswordSuccess,
        isLoading: false,
        errorMessage: null,
      ));
    } catch (e) {
      emit(AuthState.error('Failed to change password: ${e.toString()}'));
    }
  }

  Future<void> _onCheckStatusRequested(
    AuthCheckStatusRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      // Mock check status - return unauthenticated for now
      await Future.delayed(const Duration(milliseconds: 500));
      emit(AuthState.unauthenticated());
    } catch (e) {
      emit(AuthState.unauthenticated());
    }
  }

  Future<void> _onUserProfileUpdateRequested(
    AuthUserProfileUpdateRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      if (event.name != null) {
        final nameValidation = validator.Validators.validateName(event.name);
        if (nameValidation != null) {
          emit(AuthState.error(nameValidation));
          return;
        }
      }

      if (event.phoneNumber != null) {
        final phoneValidation =
            validator.Validators.validatePhoneNumber(event.phoneNumber);
        if (phoneValidation != null) {
          emit(AuthState.error(phoneValidation));
          return;
        }
      }

      // Mock update profile
      await Future.delayed(const Duration(seconds: 1));

      final updatedUser = User(
        id: state.user?.id ?? '1',
        email: state.user?.email ?? 'demo@example.com',
        name: event.name?.trim() ?? state.user?.name ?? 'Demo User',
        phoneNumber: event.phoneNumber?.trim() ?? state.user?.phoneNumber,
      );

      emit(AuthState.authenticated(updatedUser));
    } catch (e) {
      emit(AuthState.error('Failed to update profile: ${e.toString()}'));
    }
  }

  Future<void> _onBiometricToggleRequested(
    AuthBiometricToggleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      // Mock biometric toggle
      await Future.delayed(const Duration(seconds: 1));

      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(AuthState.error('Failed to toggle biometric: ${e.toString()}'));
    }
  }

  Future<void> _onPinSetRequested(
    AuthPinSetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      final pinValidation = validator.Validators.validatePin(event.pin);
      if (pinValidation != null) {
        emit(AuthState.error(pinValidation));
        return;
      }

      // Mock set PIN
      await Future.delayed(const Duration(seconds: 1));
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(AuthState.error('Failed to set PIN: ${e.toString()}'));
    }
  }

  Future<void> _onPinChangeRequested(
    AuthPinChangeRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      final currentPinValidation =
          validator.Validators.validatePin(event.currentPin);
      if (currentPinValidation != null) {
        emit(AuthState.error('Current PIN: $currentPinValidation'));
        return;
      }

      final newPinValidation = validator.Validators.validatePin(event.newPin);
      if (newPinValidation != null) {
        emit(AuthState.error('New PIN: $newPinValidation'));
        return;
      }

      if (event.currentPin == event.newPin) {
        emit(AuthState.error('New PIN must be different from current PIN'));
        return;
      }

      // Mock change PIN
      await Future.delayed(const Duration(seconds: 1));
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(AuthState.error('Failed to change PIN: ${e.toString()}'));
    }
  }
}
