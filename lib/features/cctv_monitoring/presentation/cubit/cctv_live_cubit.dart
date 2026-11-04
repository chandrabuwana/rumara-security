import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/security/security_manager.dart';
import '../../../visitor_gate/data/gate_response.dart';
import '../../data/cctv_monitoring_models.dart';
import '../../data/cctv_monitoring_repository.dart';

class CctvLiveState {
  const CctvLiveState({
    this.eventsLoading = true,
    this.events = const [],
    this.snapshotting = false,
    this.snapshotUrl,
    this.emergency,
    this.handling = false,
    this.handled = false,
    this.message,
  });

  final bool eventsLoading;
  final List<CctvEventItem> events;
  final bool snapshotting;
  final String? snapshotUrl;
  final CctvEmergencyItem? emergency;
  final bool handling;
  final bool handled;
  final String? message;

  CctvLiveState copyWith({
    bool? eventsLoading,
    List<CctvEventItem>? events,
    bool? snapshotting,
    String? snapshotUrl,
    bool clearSnapshot = false,
    bool? handling,
    bool? handled,
    String? message,
  }) {
    return CctvLiveState(
      eventsLoading: eventsLoading ?? this.eventsLoading,
      events: events ?? this.events,
      snapshotting: snapshotting ?? this.snapshotting,
      snapshotUrl: clearSnapshot ? null : (snapshotUrl ?? this.snapshotUrl),
      emergency: emergency,
      handling: handling ?? this.handling,
      handled: handled ?? this.handled,
      message: message,
    );
  }
}

class CctvLiveCubit extends Cubit<CctvLiveState> {
  CctvLiveCubit(this._repository, this.camera, {CctvEmergencyItem? emergency})
      : super(CctvLiveState(emergency: emergency));

  final CctvMonitoringRepository _repository;
  final CctvCameraItem camera;

  Future<void> loadEvents() async {
    try {
      final events = await _repository.cameraEvents(camera.id);
      if (!isClosed) emit(state.copyWith(eventsLoading: false, events: events));
    } catch (_) {
      if (!isClosed) emit(state.copyWith(eventsLoading: false));
    }
  }

  Future<void> snapshot() async {
    if (state.snapshotting) return;
    emit(state.copyWith(snapshotting: true, clearSnapshot: true));
    try {
      final url = await _repository.snapshot(camera.id);
      if (!isClosed)
        emit(state.copyWith(snapshotting: false, snapshotUrl: url));
    } on GateApiException catch (error) {
      if (!isClosed)
        emit(state.copyWith(snapshotting: false, message: error.message));
    } catch (_) {
      if (!isClosed)
        emit(state.copyWith(
            snapshotting: false, message: 'Foto gagal diambil.'));
    }
  }

  Future<void> handleEmergency() async {
    final emergency = state.emergency;
    if (emergency == null || state.handling || state.handled) return;
    emit(state.copyWith(handling: true));
    try {
      final userId = await SecurityManager.readSecurely(AppConstants.userIdKey);
      if (userId == null || userId.isEmpty) {
        throw const GateApiException(
            'Data petugas tidak ditemukan, silakan masuk ulang.');
      }
      await _repository.acceptEmergency(emergency.code, userId);
      if (!isClosed) {
        emit(state.copyWith(
          handling: false,
          handled: true,
          message: 'Panggilan darurat ditandai ditangani.',
        ));
      }
    } on GateApiException catch (error) {
      if (!isClosed)
        emit(state.copyWith(handling: false, message: error.message));
    } catch (_) {
      if (!isClosed)
        emit(state.copyWith(
            handling: false, message: 'Panggilan gagal ditandai.'));
    }
  }
}
