import '../design/branding_config.dart';

class AppConstants {
  // App Info
  // appName is white-label: driven by the bundled branding config at runtime.
  static String get appName => BrandingController.instance.appName;
  static const String appVersion = '1.0.0';

  // API Configuration
  static const String _appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String _signalRHubUrlOverride = String.fromEnvironment(
    'SIGNALR_HUB_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    // Explicit env override (API_BASE_URL, e.g. per-deploy) wins.
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride;
    }
    // White-label: respect the bundled branding config's backend URL.
    final branded = BrandingController.instance.apiBaseUrl;
    if (branded.isNotEmpty) {
      return branded;
    }
    // Final fallback.
    return 'https://api-devguardify.abb-apps.com/api/v1';
  }

  static const int connectTimeout = 60000; // Increased to 60 seconds
  static const int receiveTimeout = 60000; // Increased to 60 seconds

  // SignalR Configuration
  static String get signalRHubUrl {
    if (_signalRHubUrlOverride.isNotEmpty) {
      return _signalRHubUrlOverride;
    }

    if (_appEnv == 'prod') {
      return 'https://api-devguardify.abb-apps.com/hubs/chat';
    }

    return 'https://api-devguardify.abb-apps.com/hubs/chat';
    // return 'https://api-devguardify.abb-apps.com/hubs/chat';
  }

  // Storage Keys (white-label: prefix/scoped per-company to avoid collision)
  static String get tokenKey => BrandingController.instance.tokenKey;
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String userIdKey = 'user_id';
  static const String biometricEnabledKey = 'biometric_enabled';
  static const String pinKey = 'user_pin';
  static const String shiftDetailIdKey = 'shift_detail_id';
  static const String attendanceIdKey = 'attendance_id';

  // Security Configuration
  static String get encryptionKey => BrandingController.instance.encryptionKey;
  static const int sessionTimeoutMinutes = 30;
  static const int maxLoginAttempts = 5;
  static const int lockoutDurationMinutes = 15;

  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int pinLength = 6;

  // Error Messages
  static const String genericErrorMessage =
      'Terjadi kesalahan. Silakan coba lagi.';
  static const String networkErrorMessage =
      'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
  static const String unauthorizedErrorMessage =
      'Sesi Anda telah berakhir. Silakan login kembali.';
  static const String biometricNotAvailableMessage =
      'Biometrik tidak tersedia di perangkat ini.';
}
