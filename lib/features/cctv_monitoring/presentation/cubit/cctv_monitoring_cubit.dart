import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/security/security_manager.dart';
import '../../../visitor_gate/data/gate_response.dart';
import '../../data/cctv_monitoring_models.dart';
import '../../data/cctv_monitoring_repository.dart';

class CctvMonitoringState {
  const CctvMonitoringState({
    this.loading = true,
    this.error,
    this.forbidden = false,
    this.summary = const CctvSummaryInfo(),
    this.cameras = const [],
    this.emergencies = const [],
    this.filter = CctvMonitoringState.all,
    this.accepting,
  });

  static const String all = '__all__';
  static const String offline = '__offline__';

  final bool loading;
  final String? error;
  final bool forbidden;
  final CctvSummaryInfo summary;
  final List<CctvCameraItem> cameras;
  final List<CctvEmergencyItem> emergencies;
  final String filter;
  final String? accepting;

  List<String> get groups {
    final result = <String>[];
    for (final camera in cameras) {
      final group = camera.groupLabel;
      if (group != null && !result.contains(group)) result.add(group);
    }
    return result;
  }

  int get onlineCount => cameras.where((camera) => camera.isOnline).length;
  int get offlineCount => cameras.length - onlineCount;

  List<CctvCameraItem> get visibleCameras {
    switch (filter) {
      case all:
        return cameras;
      case offline:
        return cameras.where((camera) => !camera.isOnline).toList();
      default:
        return cameras.where((camera) => camera.groupLabel == filter).toList();
    }
  }

  List<CctvEventItem> get recentDetections {
    final since = DateTime.now().subtract(const Duration(minutes: 30));
    return summary.recentEvents
        .where((event) =>
            event.isDetection && (event.occurredAt?.isAfter(since) ?? false))
        .take(3)
        .toList();
  }

  bool hasMotion(String cameraId) {
    final since = DateTime.now().subtract(const Duration(minutes: 2));
    return summary.recentEvents.any(
      (event) =>
          event.cameraId == cameraId &&
          event.isDetection &&
          (event.occurredAt?.isAfter(since) ?? false),
    );
  }

  CctvMonitoringState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    bool? forbidden,
    CctvSummaryInfo? summary,
    List<CctvCameraItem>? cameras,
    List<CctvEmergencyItem>? emergencies,
    String? filter,
    String? accepting,
    bool clearAccepting = false,
  }) {
    return CctvMonitoringState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      forbidden: forbidden ?? this.forbidden,
      summary: summary ?? this.summary,
      cameras: cameras ?? this.cameras,
      emergencies: emergencies ?? this.emergencies,
      filter: filter ?? this.filter,
      accepting: clearAccepting ? null : (accepting ?? this.accepting),
    );
  }
}

class CctvMonitoringCubit extends Cubit<CctvMonitoringState> {
  CctvMonitoringCubit(this._repository) : super(const CctvMonitoringState());

  final CctvMonitoringRepository _repository;
  Timer? _timer;

  Future<void> load({bool silent = false}) async {
    if (!silent) emit(state.copyWith(loading: true, clearError: true));
    try {
      final cameras = await _repository.cameras();
      final summary = await _repository.summary();
      final emergencies = await _repository.pendingEmergencies();
      if (isClosed) return;
      emit(state.copyWith(
        loading: false,
        clearError: true,
        forbidden: false,
        cameras: cameras,
        summary: summary,
        emergencies: emergencies,
      ));
    } on GateApiException catch (error) {
      if (isClosed) return;
      emit(state.copyWith(
        loading: false,
        error: silent ? state.error : error.message,
        forbidden: error.isForbidden,
      ));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(
        loading: false,
        error: silent ? state.error : 'Data kamera gagal dimuat.',
      ));
    }
  }

  void startAutoRefresh() {
    _timer?.cancel();
    _timer =
        Timer.periodic(const Duration(seconds: 15), (_) => load(silent: true));
  }

  void setFilter(String filter) => emit(state.copyWith(filter: filter));

  Future<String?> accept(String code) async {
    if (state.accepting != null) return null;
    emit(state.copyWith(accepting: code));
    try {
      final userId = await SecurityManager.readSecurely(AppConstants.userIdKey);
      if (userId == null || userId.isEmpty) {
        throw const GateApiException(
            'Data petugas tidak ditemukan, silakan masuk ulang.');
      }
      await _repository.acceptEmergency(code, userId);
      if (isClosed) return null;
      emit(state.copyWith(
        clearAccepting: true,
        emergencies:
            state.emergencies.where((item) => item.code != code).toList(),
      ));
      await load(silent: true);
      return null;
    } on GateApiException catch (error) {
      if (!isClosed) emit(state.copyWith(clearAccepting: true));
      return error.message;
    } catch (_) {
      if (!isClosed) emit(state.copyWith(clearAccepting: true));
      return 'Panggilan gagal ditandai.';
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
