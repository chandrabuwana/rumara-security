import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_use_case.dart';
import '../../features/bmi/data/datasources/bmi_remote_data_source.dart';
import '../../features/chat/data/datasources/chat_remote_data_source.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/news/domain/repositories/news_repository.dart';
import '../../features/news/presentation/bloc/news_bloc.dart';
import '../../features/test_result/data/datasources/test_result_api_data_source.dart';
import '../constants/app_constants.dart';
import '../navigation/app_navigator_key.dart';
import '../security/security_manager.dart';

/// Injection Module - Centralized Dependency Registration
/// Semua dependencies diregister di sini untuk memudahkan maintenance
@module
abstract class InjectionModule {
  // ========================================
  // External Dependencies (Third Party)
  // ========================================

  /// SharedPreferences - Persistent Storage
  @preResolve
  @lazySingleton
  Future<SharedPreferences> get sharedPreferences =>
      SharedPreferences.getInstance();

  /// Dio - HTTP Client
  @lazySingleton
  Dio get dio {
    final dio = Dio();

    // Base Configuration
    dio.options.baseUrl = AppConstants.baseUrl;
    dio.options.connectTimeout =
        const Duration(seconds: 60); // Increased to 60 seconds
    dio.options.receiveTimeout =
        const Duration(seconds: 60); // Increased to 60 seconds

    // ValidateStatus - Jangan throw exception untuk 4xx error
    // Biarkan kita handle sendiri di repository
    dio.options.validateStatus = (status) {
      // Accept semua status code, handle error di repository layer
      return status != null && status < 500;
    };

    // Headers
    dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add Auth Token Interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add authentication token from secure storage
          final token =
              await SecurityManager.readSecurely(AppConstants.tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // Log khusus untuk AssessmentDetail endpoint
          if (options.path.contains('AssesmentDetail')) {
            print('🎯 === ASSESSMENT DETAIL REQUEST ===');
            print('🎯 URL: ${options.uri}');
            print('🎯 Method: ${options.method}');
            print('🎯 Headers: ${options.headers}');
            print('🎯 Request Body: ${options.data}');
            print('🎯 ===================================');
          }

          // Log untuk Areas/list untuk debugging timeout
          if (options.path.contains('Areas/list')) {
            options.extra['start_time'] = DateTime.now();
            print('📍 === AREAS/LIST REQUEST ===');
            print('📍 URL: ${options.uri}');
            print('📍 Method: ${options.method}');
            print('📍 Headers: ${options.headers}');
            print('📍 Request Body: ${options.data}');
            print('📍 Timeout: ${dio.options.receiveTimeout}');
            print('📍 ===========================');
          }

          handler.next(options);
        },
        onResponse: (response, handler) async {
          // Global unauthorized handler.
          // NOTE: validateStatus allows 4xx, so 401 arrives here (not in onError).
          final statusCode = response.statusCode;
          final path = response.requestOptions.path;

          final isAuthEndpoint = path.contains('/auth/') ||
              path.contains('/Auth/') ||
              path.contains('/login') ||
              path.contains('/Login');

          if (statusCode == 401 && !isAuthEndpoint) {
            await SecurityManager.deleteSecurely(AppConstants.tokenKey);
            await SecurityManager.deleteSecurely(AppConstants.refreshTokenKey);

            final navigator = AppNavigatorKey.navigatorKey.currentState;
            if (navigator != null) {
              navigator.pushNamedAndRemoveUntil('/login', (route) => false);
              final replaced =
                  response.headers.value('session-replaced') == 'true';
              final expired = response.headers.value('token-expired') == 'true';
              final endpoint = Uri.tryParse(path)?.path ?? path;
              final message = replaced
                  ? 'Sesi berakhir. Akun Anda masuk di perangkat lain.'
                  : expired
                      ? 'Sesi Anda sudah habis. Silakan masuk kembali.'
                      : 'Sesi ditolak server (401) saat membuka $endpoint. Silakan masuk kembali.';
              ScaffoldMessenger.maybeOf(navigator.context)?.showSnackBar(
                SnackBar(
                  content: Text(message),
                  duration: const Duration(seconds: 6),
                ),
              );
            }
          }

          // Log response untuk AssessmentDetail
          if (response.requestOptions.path.contains('AssesmentDetail')) {
            print('✅ === ASSESSMENT DETAIL RESPONSE ===');
            print('✅ Status Code: ${response.statusCode}');
            print('✅ Response Data: ${response.data}');
            print('✅ ===================================');
          }

          // Log response untuk Areas/list
          if (response.requestOptions.path.contains('Areas/list')) {
            final startTime =
                response.requestOptions.extra['start_time'] as DateTime?;
            final duration =
                startTime != null ? DateTime.now().difference(startTime) : null;
            print('✅ === AREAS/LIST RESPONSE ===');
            print('✅ Status: ${response.statusCode}');
            print('✅ Response time: ${duration?.inMilliseconds}ms');
            print('✅ ===========================');
          }

          handler.next(response);
        },
        onError: (error, handler) async {
          // Log error untuk AssessmentDetail
          if (error.requestOptions.path.contains('AssesmentDetail')) {
            print('❌ === ASSESSMENT DETAIL ERROR ===');
            print('❌ Error: ${error.message}');
            print('❌ Response: ${error.response?.data}');
            print('❌ ===================================');
          }
          handler.next(error);
        },
      ),
    );

    // Logging Interceptor (for debugging)
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        requestHeader: true,
        responseHeader: false,
      ),
    );

    return dio;
  }

  // ========================================
  // API Log Service Dependencies
  // ========================================

  // ApiLogService is auto-registered by @LazySingleton annotation in api_log_service.dart
  // No manual registration needed here

  // ========================================
  // Auth Feature Dependencies
  // ========================================

  /// Auth Remote Data Source
  @lazySingleton
  AuthRemoteDataSource authRemoteDataSource(Dio dio) {
    return AuthRemoteDataSource(dio);
  }

  /// Auth Repository Implementation
  @lazySingleton
  AuthRepository authRepository(AuthRemoteDataSource remoteDataSource) {
    return AuthRepositoryImpl(remoteDataSource: remoteDataSource);
  }

  /// Login Repository (for LoginUseCase)
  @lazySingleton
  LoginRepository loginRepository(AuthRemoteDataSource remoteDataSource) {
    return AuthRepositoryImpl(remoteDataSource: remoteDataSource);
  }

  // ========================================
  // Chat Feature Dependencies
  // ========================================

  /// Chat Remote Data Source
  /// Note: ChatRemoteDataSource is auto-registered by injectable
  /// because it uses @lazySingleton annotation

  /// Chat Repository Implementation
  @lazySingleton
  ChatRepository chatRepository(ChatRemoteDataSource remoteDataSource) {
    return ChatRepositoryImpl(remoteDataSource);
  }

  /// SignalR Chat Service
  /// Note: SignalRChatService is auto-registered by @lazySingleton annotation

  /// Chat Bloc
  /// Note: ChatBloc is auto-registered by @injectable annotation in chat_bloc.dart
  /// No manual registration needed here

  // ========================================
  // News Feature Dependencies
  // ========================================

  // NewsRemoteDataSource and NewsRepository are auto-registered by @LazySingleton annotation
  // No manual registration needed here

  /// News Bloc
  @injectable
  NewsBloc newsBloc(NewsRepository newsRepository) {
    return NewsBloc(newsRepository);
  }

  // ========================================
  // BMI Feature Dependencies
  // ========================================

  /// BMI Remote Data Source
  @lazySingleton
  BmiRemoteDataSource bmiRemoteDataSource(Dio dio) {
    return BmiRemoteDataSource(dio);
  }

  // ========================================
  // Test Result Feature Dependencies
  // ========================================

  /// Test Result API Data Source
  @lazySingleton
  TestResultApiDataSource testResultApiDataSource(Dio dio) {
    return TestResultApiDataSource(dio);
  }

  // TestResultRemoteDataSource is auto-registered by @LazySingleton annotation
  // No manual registration needed here

  // ========================================
  // Schedule Feature Dependencies
  // ========================================

  // ScheduleRemoteDataSource, ScheduleRepository, use cases, and BLoC
  // are all auto-registered with @Injectable/@LazySingleton annotations
  // No manual registration needed

  // ========================================
  // Personnel Feature Dependencies
  // ========================================

  // All personnel dependencies are auto-registered with annotations:
  // - PersonnelRemoteDataSource: @LazySingleton(as: PersonnelRemoteDataSource)
  // - PersonnelRepository: @LazySingleton
  // - Use cases: @Injectable
  // - PersonnelBloc: @Injectable

  // ========================================
  // Tambahkan dependencies feature lain di sini
  // Contoh:
  // - Profile Feature
  // - Attendance Feature
  // - Patrol Feature
  // dll
  // ========================================
}
