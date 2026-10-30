import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_use_case.dart';
import '../datasources/auth_remote_data_source.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/constants/app_constants.dart';

class AuthRepositoryImpl implements AuthRepository, LoginRepository {
  final AuthRemoteDataSource remoteDataSource;

  static const String _deviceIdStorageKey = 'device_id';

  AuthRepositoryImpl({required this.remoteDataSource});

  Future<String> _getOrCreateDeviceId() async {
    final cached = await SecurityManager.readSecurely(_deviceIdStorageKey);
    if (cached != null && cached.isNotEmpty) return cached;

    String? id;
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        id = info.id;
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        id = info.identifierForVendor;
      }
    } catch (_) {
      id = null;
    }

    final deviceId = (id != null && id.isNotEmpty) ? id : _generateRandomId();
    await SecurityManager.storeSecurely(_deviceIdStorageKey, deviceId);
    return deviceId;
  }

  String _getPlatformName() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }

  String _generateRandomId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    try {
      String firebaseToken = '';
      try {
        final messaging = FirebaseMessaging.instance;
        final settings = await messaging.requestPermission();
        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          firebaseToken = await messaging.getToken() ?? '';
        }
      } catch (_) {
        firebaseToken = '';
      }

      final deviceId = await _getOrCreateDeviceId();
      final platform = _getPlatformName();

      // Call API
      final response = await remoteDataSource.login({
        'Username': username,
        'Password': password,
        'FromMobile': true,
        'FirebaseToken': firebaseToken,
        'DeviceId': deviceId,
        'Platform': platform,
      });

      // Check if request succeeded
      if (!response.succeeded || response.data == null) {
        // Handle specific error cases
        // Jika code 403 (user not active), tampilkan pesan dari API
        if (response.code == 403) {
          return LoginResult.failure(
            AuthenticationFailure(response.message.isNotEmpty 
                ? response.message 
                : 'Akun belum aktif. Silakan hubungi administrator untuk verifikasi akun.'),
          );
        }
        
        if (response.code == 404) {
          return LoginResult.failure(
            AuthenticationFailure('Username tidak terdaftar di RUMARA.'),
          );
        }

        // Login gagal - tampilkan pesan user-friendly
        // Apapun error dari API (404, 400, dll), tampilkan pesan yang sama
        return LoginResult.failure(
          AuthenticationFailure('Username atau password salah'),
        );
      }

      final data = response.data!;

      // Convert to entities
      final token = data.authToken.toEntity();

      print('🔐 ========================================');
      print('🔐 LOGIN SUCCESS - SAVING USER DATA');
      print('🔐 ========================================');
      print('🔐 User ID from API: ${data.user.id}');
      print('🔐 Username: ${data.user.username}');
      print('🔐 Full Name: ${data.user.fullName}');
      print('🔐 Email: ${data.user.mail}');

      // Clear old data first to prevent conflicts
      print('🔐 Clearing old data...');
      await SecurityManager.deleteSecurely(AppConstants.userIdKey);
      await SecurityManager.deleteSecurely('user_username');
      await SecurityManager.deleteSecurely('user_fullname');
      await SecurityManager.deleteSecurely('user_mail');
      await SecurityManager.deleteSecurely('user_role_id');
      await SecurityManager.deleteSecurely('user_role_name');
      print('🔐 Old data cleared!');

      // Save token to secure storage with key "token_guardify"
      await SecurityManager.storeSecurely(
        AppConstants.tokenKey,
        data.rawToken,
      );
      print('✅ Saved token');

      // Save refresh token
      await SecurityManager.storeSecurely(
        AppConstants.refreshTokenKey,
        data.refreshToken,
      );
      print('✅ Saved refresh token');

      // Save user ID to secure storage for profile API
      await SecurityManager.storeSecurely(
        AppConstants.userIdKey,
        data.user.id,
      );
      print('✅ Saved user ID: ${data.user.id}');

      // Verify data tersimpan dengan benar
      final savedUserId = await SecurityManager.readSecurely(AppConstants.userIdKey);
      print('🔍 VERIFICATION - Read back user ID: $savedUserId');
      
      if (savedUserId == null || savedUserId.isEmpty) {
        print('❌ ERROR: User ID tidak tersimpan dengan benar!');
      } else if (savedUserId != data.user.id) {
        print('❌ ERROR: User ID tidak match! Expected: ${data.user.id}, Got: $savedUserId');
      } else {
        print('✅ VERIFIED: User ID tersimpan dengan benar!');
      }
      print('🔐 ========================================');
      print('');

      // Save username to secure storage
      await SecurityManager.storeSecurely(
        'user_username',
        data.user.username,
      );

      // Save mail to secure storage
      await SecurityManager.storeSecurely(
        'user_mail',
        data.user.mail,
      );

      // Save full name to secure storage
      await SecurityManager.storeSecurely(
        'user_fullname',
        data.user.fullName,
      );

      // Save primary role ID to secure storage
      final roleId = data.user.primaryRoleId;
      print('🔐 Saving role ID: $roleId');
      await SecurityManager.storeSecurely(
        'user_role_id',
        roleId,
      );
      print('✅ Saved role ID');
      
      // Verify role ID was saved correctly
      final verifyRoleId = await SecurityManager.readSecurely('user_role_id');
      print('🔍 VERIFICATION - Read back role ID: $verifyRoleId');
      if (verifyRoleId == roleId) {
        print('✅ VERIFIED: Role ID tersimpan dengan benar!');
      } else {
        print('❌ ERROR: Role ID tidak tersimpan dengan benar!');
        print('❌ Expected: $roleId, Got: $verifyRoleId');
      }

      // Save primary role name to secure storage
      final roleName = data.user.primaryRoleName;
      print('🔐 Saving role name: $roleName');
      await SecurityManager.storeSecurely(
        'user_role_name',
        roleName,
      );
      print('✅ Saved role name');

      // Create use case AuthToken from entity
      final useCaseToken = AuthToken(
        accessToken: token.accessToken,
        refreshToken: token.refreshToken,
        tokenType: token.tokenType,
        expiresIn: token.expiresIn,
        issuedAt: token.issuedAt,
      );

      // Create LoginUser from response
      final loginUser = LoginUser(
        id: data.user.id,
        username: data.user.username,
        fullName: data.user.fullName,
        email: data.user.mail,
        roleIds: data.user.role.map((r) => r.id).toList(),
        roleNames: data.user.role.map((r) => r.nama).toList(),
      );

      return LoginResult.success(useCaseToken, loginUser);
    } on DioException catch (e) {
      // Tangkap semua DioException (termasuk error 404, 400, 401, 403)
      final statusCode = e.response?.statusCode;

      // Semua error authentication (4xx) tampilkan pesan yang sama
      // Untuk keamanan dan UX yang lebih baik
      if (statusCode != null && statusCode >= 400 && statusCode < 500) {
        return LoginResult.failure(
          AuthenticationFailure('Username atau password salah'),
        );
      }

      // Error server (5xx) atau network error
      return LoginResult.failure(
        ServerFailure('Terjadi kesalahan pada server. Silakan coba lagi.'),
      );
    } catch (e) {
      // Catch all other exceptions (parsing error, dll)
      // Juga tampilkan sebagai authentication failure untuk keamanan
      return LoginResult.failure(
        ServerFailure('Login berhasil diproses server, tetapi data akun tidak dapat dibaca aplikasi.'),
      );
    }
  }

  @override
  Future<RegisterResult> register({
    required String email,
    required String password,
    required String name,
    String? phoneNumber,
  }) async {
    // TODO: Implement register when API is available
    return RegisterResult.failure(
      ServerFailure('Register not implemented yet'),
    );
  }

  @override
  Future<LogoutResult> logout() async {
    try {
      // Clear tokens and user data from secure storage
      await SecurityManager.deleteSecurely(AppConstants.tokenKey);
      await SecurityManager.deleteSecurely(AppConstants.refreshTokenKey);
      await SecurityManager.deleteSecurely(AppConstants.userIdKey);
      await SecurityManager.deleteSecurely('user_username');
      await SecurityManager.deleteSecurely('user_fullname');
      await SecurityManager.deleteSecurely('user_role_id');
      await SecurityManager.deleteSecurely('user_role_name');
      return LogoutResult.success();
    } catch (e) {
      return LogoutResult.failure(
        ServerFailure(e.toString()),
      );
    }
  }

  @override
  Future<TokenResult> refreshToken() async {
    // TODO: Implement refresh token when API is available
    return TokenResult.failure(
      ServerFailure('Refresh token not implemented yet'),
    );
  }

  @override
  Future<UserResult> getCurrentUser() async {
    // TODO: Implement get current user when API is available
    return UserResult.failure(
      ServerFailure('Get current user not implemented yet'),
    );
  }

  @override
  Future<PasswordResult> forgotPassword(String email) async {
    // TODO: Implement forgot password when API is available
    return PasswordResult.failure(
      ServerFailure('Forgot password not implemented yet'),
    );
  }

  @override
  Future<PasswordResult> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    // TODO: Implement reset password when API is available
    return PasswordResult.failure(
      ServerFailure('Reset password not implemented yet'),
    );
  }

  @override
  Future<PasswordResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // TODO: Implement change password when API is available
    return PasswordResult.failure(
      ServerFailure('Change password not implemented yet'),
    );
  }

  @override
  Future<EmailResult> verifyEmail(String token) async {
    // TODO: Implement verify email when API is available
    return EmailResult.failure(
      ServerFailure('Verify email not implemented yet'),
    );
  }

  @override
  Future<EmailResult> resendEmailVerification() async {
    // TODO: Implement resend email verification when API is available
    return EmailResult.failure(
      ServerFailure('Resend email verification not implemented yet'),
    );
  }

  @override
  Future<BiometricResult> loginWithBiometric() async {
    // TODO: Implement biometric login when needed
    return BiometricResult.failure(
      ServerFailure('Biometric login not implemented yet'),
    );
  }

  @override
  Future<BiometricResult> enableBiometric() async {
    // TODO: Implement enable biometric when needed
    return BiometricResult.failure(
      ServerFailure('Enable biometric not implemented yet'),
    );
  }

  @override
  Future<BiometricResult> disableBiometric() async {
    // TODO: Implement disable biometric when needed
    return BiometricResult.failure(
      ServerFailure('Disable biometric not implemented yet'),
    );
  }

  @override
  Future<PinResult> loginWithPin(String pin) async {
    // TODO: Implement pin login when needed
    return PinResult.failure(
      ServerFailure('Pin login not implemented yet'),
    );
  }

  @override
  Future<PinResult> setPin(String pin) async {
    // TODO: Implement set pin when needed
    return PinResult.failure(
      ServerFailure('Set pin not implemented yet'),
    );
  }

  @override
  Future<PinResult> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    // TODO: Implement change pin when needed
    return PinResult.failure(
      ServerFailure('Change pin not implemented yet'),
    );
  }

  @override
  Future<ProfileResult> updateProfile({
    String? name,
    String? phoneNumber,
  }) async {
    // TODO: Implement update profile when API is available
    return ProfileResult.failure(
      ServerFailure('Update profile not implemented yet'),
    );
  }

  @override
  Future<bool> isLoggedIn() async {
    try {
      final token = await SecurityManager.readSecurely(AppConstants.tokenKey);
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> hasValidToken() async {
    try {
      final token = await SecurityManager.readSecurely(AppConstants.tokenKey);
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
