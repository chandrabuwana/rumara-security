import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/attendance/domain/usecases/get_attendance_status_usecase.dart'
    show GetAttendanceStatusUseCase, UserAttendanceStatus;
import '../constants/app_constants.dart';
import '../constants/enums.dart';
import '../di/injection.dart';
import '../security/security_manager.dart';
import '../utils/user_role_helper.dart';
import 'background_location_permission_helper.dart';

class LiveLocationTracker {
  LiveLocationTracker._();

  static final LiveLocationTracker instance = LiveLocationTracker._();

  static const int minIntervalSeconds = 15;

  StreamSubscription<Position>? _subscription;
  DateTime? _lastSentAt;
  bool _sending = false;
  bool _starting = false;
  int _intervalSeconds = minIntervalSeconds;

  bool get isRunning => _subscription != null;

  Future<void> resume() async {
    if (isRunning || _starting) return;
    try {
      if (!await BackgroundLocationPermissionHelper.hasAcceptedDisclosure()) {
        return;
      }
      if (!await UserRoleHelper.isUserLoggedIn()) return;
      if (await UserRoleHelper.getUserRole() == UserRole.pengawas) return;
      final userId = await UserRoleHelper.getUserId();
      if (userId == null || userId.isEmpty) return;
      final status = await getIt<GetAttendanceStatusUseCase>()(userId);
      final checkedIn = status.fold(
        (_) => false,
        (result) => result.status == UserAttendanceStatus.checkedIn,
      );
      if (checkedIn) await start();
    } catch (e) {
      debugPrint('[LiveLocationTracker] resume gagal: $e');
    }
  }

  Future<void> start() async {
    if (isRunning || _starting) return;
    _starting = true;
    try {
      if (!await _hasPermission()) return;
      _intervalSeconds = await _loadInterval();
      _lastSentAt = null;
      _subscription = Geolocator.getPositionStream(
        locationSettings: _settings(),
      ).listen(
        _onPosition,
        onError: (Object e) =>
            debugPrint('[LiveLocationTracker] stream error: $e'),
      );
    } catch (e) {
      debugPrint('[LiveLocationTracker] start gagal: $e');
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _lastSentAt = null;
  }

  LocationSettings _settings() {
    final interval = Duration(seconds: _intervalSeconds);
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: interval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Rumara Security',
          notificationText: 'Lokasi Anda dibagikan selama jam kerja',
          notificationChannelName: 'Lokasi petugas',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high);
  }

  Future<bool> _hasPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<int> _loadInterval() async {
    try {
      final token = await SecurityManager.readSecurely(AppConstants.tokenKey);
      final response = await getIt<Dio>().get(
        '/security/location-config',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final body = response.data;
      if (body is Map) {
        final data = body['Data'] ?? body['data'];
        if (data is Map) {
          final value = data['IntervalSeconds'] ?? data['intervalSeconds'];
          final seconds = value is num ? value.toInt() : int.tryParse('$value');
          if (seconds != null && seconds >= minIntervalSeconds) return seconds;
        }
      }
    } catch (e) {
      debugPrint('[LiveLocationTracker] gagal memuat interval: $e');
    }
    return minIntervalSeconds;
  }

  Future<void> _onPosition(Position position) async {
    final now = DateTime.now();
    final last = _lastSentAt;
    if (_sending) return;
    if (last != null &&
        now.difference(last).inSeconds < _intervalSeconds - 1) {
      return;
    }
    _sending = true;
    try {
      final token = await SecurityManager.readSecurely(AppConstants.tokenKey);
      if (token == null || token.isEmpty) {
        await stop();
        return;
      }
      await getIt<Dio>().post(
        '/CurrentLocation/update',
        data: {
          'Latitude': position.latitude,
          'Longitude': position.longitude,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      _lastSentAt = now;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) await stop();
      debugPrint('[LiveLocationTracker] kirim lokasi gagal: ${e.message}');
    } catch (e) {
      debugPrint('[LiveLocationTracker] kirim lokasi gagal: $e');
    } finally {
      _sending = false;
    }
  }
}
