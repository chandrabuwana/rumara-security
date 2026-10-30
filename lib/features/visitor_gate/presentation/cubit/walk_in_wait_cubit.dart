import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/gate_response.dart';
import '../../data/visitor_gate_models.dart';
import '../../data/visitor_gate_repository.dart';

enum WalkInPhase {
  waiting,
  noResponse,
  approved,
  rejected,
  expired,
  cancelled,
  admitted
}

class WalkInWaitState {
  const WalkInWaitState({
    required this.ticket,
    required this.total,
    required this.remaining,
    this.phase = WalkInPhase.waiting,
    this.status,
    this.busy = false,
    this.error,
    this.record,
  });

  final WalkInTicket ticket;
  final int total;
  final int remaining;
  final WalkInPhase phase;
  final WalkInStatus? status;
  final bool busy;
  final String? error;
  final VisitorVisitRecord? record;

  WalkInWaitState copyWith({
    int? total,
    int? remaining,
    WalkInPhase? phase,
    WalkInStatus? status,
    bool? busy,
    String? error,
    bool clearError = false,
    VisitorVisitRecord? record,
  }) {
    return WalkInWaitState(
      ticket: ticket,
      total: total ?? this.total,
      remaining: remaining ?? this.remaining,
      phase: phase ?? this.phase,
      status: status ?? this.status,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      record: record ?? this.record,
    );
  }
}

class WalkInWaitCubit extends Cubit<WalkInWaitState> {
  WalkInWaitCubit(this._repository, WalkInTicket ticket)
      : super(WalkInWaitState(
          ticket: ticket,
          total: ticket.waitSeconds,
          remaining: ticket.waitSeconds,
        ));

  final VisitorGateRepository _repository;
  Timer? _countdown;
  Timer? _poll;
  bool _polling = false;

  bool get _open =>
      state.phase == WalkInPhase.waiting ||
      state.phase == WalkInPhase.noResponse;

  void start() {
    _startCountdown(state.ticket.waitSeconds);
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    refresh();
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    emit(state.copyWith(
        total: seconds, remaining: seconds, phase: WalkInPhase.waiting));
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isClosed || state.phase != WalkInPhase.waiting) {
        timer.cancel();
        return;
      }
      final next = state.remaining - 1;
      if (next <= 0) {
        timer.cancel();
        emit(state.copyWith(remaining: 0, phase: WalkInPhase.noResponse));
      } else {
        emit(state.copyWith(remaining: next));
      }
    });
  }

  Future<void> refresh() async {
    if (_polling || !_open) return;
    _polling = true;
    try {
      final status = await _repository.walkInStatus(state.ticket.requestId);
      if (isClosed || !_open) return;
      switch (status.state) {
        case WalkInDecisionState.approved:
          _stopTimers();
          emit(state.copyWith(status: status, phase: WalkInPhase.approved));
          break;
        case WalkInDecisionState.rejected:
          _stopTimers();
          emit(state.copyWith(status: status, phase: WalkInPhase.rejected));
          break;
        case WalkInDecisionState.expired:
          _stopTimers();
          emit(state.copyWith(status: status, phase: WalkInPhase.expired));
          break;
        case WalkInDecisionState.waiting:
          emit(state.copyWith(status: status));
          break;
      }
    } catch (_) {
      _polling = false;
    } finally {
      _polling = false;
    }
  }

  void waitMore() {
    if (state.phase != WalkInPhase.noResponse) return;
    _startCountdown(state.ticket.waitSeconds);
  }

  Future<void> admitApproved() => _act(() async {
        final record = await _repository.checkInWalkIn(
          state.ticket.requestId,
          state.ticket.guestCount,
        );
        emit(state.copyWith(
            busy: false, phase: WalkInPhase.admitted, record: record));
      });

  Future<void> admitDefault() => _act(() async {
        await _repository.decideWalkIn(
          state.ticket.requestId,
          approve: true,
          note: VisitorGateRepository.defaultAccessNote,
        );
        final record = await _repository.checkInWalkIn(
          state.ticket.requestId,
          state.ticket.guestCount,
        );
        emit(state.copyWith(
            busy: false, phase: WalkInPhase.admitted, record: record));
      });

  Future<void> cancel() => _act(() async {
        await _repository.decideWalkIn(
          state.ticket.requestId,
          approve: false,
          note: VisitorGateRepository.cancelNote,
        );
        emit(state.copyWith(busy: false, phase: WalkInPhase.cancelled));
      });

  Future<void> _act(Future<void> Function() action) async {
    if (state.busy) return;
    _stopTimers();
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await action();
    } on GateApiException catch (error) {
      if (!isClosed) emit(state.copyWith(busy: false, error: error.message));
      await _resync();
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(
            busy: false, error: 'Terjadi kesalahan, silakan coba lagi.'));
      }
      await _resync();
    }
  }

  Future<void> _resync() async {
    if (isClosed) return;
    try {
      final status = await _repository.walkInStatus(state.ticket.requestId);
      if (isClosed) return;
      final phase = switch (status.state) {
        WalkInDecisionState.approved => WalkInPhase.approved,
        WalkInDecisionState.rejected => WalkInPhase.rejected,
        WalkInDecisionState.expired => WalkInPhase.expired,
        WalkInDecisionState.waiting =>
          state.remaining > 0 ? WalkInPhase.waiting : WalkInPhase.noResponse,
      };
      emit(state.copyWith(status: status, phase: phase));
      if (phase == WalkInPhase.waiting || phase == WalkInPhase.noResponse) {
        _poll?.cancel();
        _poll = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
        if (phase == WalkInPhase.waiting) _startCountdown(state.remaining);
      }
    } catch (_) {
      return;
    }
  }

  void _stopTimers() {
    _countdown?.cancel();
    _poll?.cancel();
  }

  @override
  Future<void> close() {
    _stopTimers();
    return super.close();
  }
}
