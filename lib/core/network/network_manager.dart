import 'dart:io';
import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import '../constants/app_constants.dart';
import '../security/security_manager.dart';

@lazySingleton
class NetworkManager {
  late final Dio _dio;
  static final NetworkManager _instance = NetworkManager._internal();

  factory NetworkManager() => _instance;

  NetworkManager._internal() {
    _dio = Dio();
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.options.baseUrl = AppConstants.baseUrl;
    _dio.options.connectTimeout = const Duration(
      milliseconds: AppConstants.connectTimeout,
    );
    _dio.options.receiveTimeout = const Duration(
      milliseconds: AppConstants.receiveTimeout,
    );

    // Request interceptor for authentication and security
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add authentication token
          final token = await SecurityManager.readSecurely(
            AppConstants.tokenKey,
          );
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // Add security headers
          options.headers['X-App-Version'] = AppConstants.appVersion;
          options.headers['X-Platform'] = Platform.isAndroid
              ? 'android'
              : 'ios';
          options.headers['X-Request-ID'] =
              SecurityManager.generateSecureToken();

          // Add app signature for request verification
          options.headers['X-App-Signature'] =
              SecurityManager.generateAppSignature();

          handler.next(options);
        },
        onResponse: (response, handler) {
          // Verify response integrity if needed
          handler.next(response);
        },
        onError: (error, handler) async {
          // Handle token refresh on 401
          if (error.response?.statusCode == 401) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              // Retry the original request
              final originalRequest = error.requestOptions;
              final token = await SecurityManager.readSecurely(
                AppConstants.tokenKey,
              );
              originalRequest.headers['Authorization'] = 'Bearer $token';

              final response = await _dio.fetch(originalRequest);
              handler.resolve(response);
              return;
            }
          }

          handler.next(error);
        },
      ),
    );

    // Logging interceptor (only in debug mode)
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: true,
          responseHeader: false,
        ),
      );
      _dio.interceptors.add(ChuckerDioInterceptor());
    }
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await SecurityManager.readSecurely(
        AppConstants.refreshTokenKey,
      );
      if (refreshToken == null) return false;

      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final newToken = response.data['access_token'];
        final newRefreshToken = response.data['refresh_token'];

        await SecurityManager.storeSecurely(AppConstants.tokenKey, newToken);
        await SecurityManager.storeSecurely(
          AppConstants.refreshTokenKey,
          newRefreshToken,
        );

        return true;
      }
    } catch (e) {
      // Clear tokens on refresh failure
      await SecurityManager.deleteSecurely(AppConstants.tokenKey);
      await SecurityManager.deleteSecurely(AppConstants.refreshTokenKey);
    }

    return false;
  }

  // GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // Download file
  Future<Response> download(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.download(
      urlPath,
      savePath,
      onReceiveProgress: onReceiveProgress,
      queryParameters: queryParameters,
      options: options,
    );
  }
}
