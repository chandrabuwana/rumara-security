import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/gate_response.dart';
import '../../data/visitor_gate_models.dart';
import '../../data/visitor_gate_repository.dart';

enum VisitorActionStatus { idle, busy, success, failure }

class VisitorActionState {
  const VisitorActionState({
    this.status = VisitorActionStatus.idle,
    this.result,
    this.record,
    this.message,
  });

  final VisitorActionStatus status;
  final VisitorScanResult? result;
  final VisitorVisitRecord? record;
  final String? message;

  bool get busy => status == VisitorActionStatus.busy;
}

class VisitorActionCubit extends Cubit<VisitorActionState> {
  VisitorActionCubit(this._repository) : super(const VisitorActionState());

  final VisitorGateRepository _repository;

  Future<void> scan(String code) => _run(() async {
        final result = await _repository.scan(code);
        emit(VisitorActionState(
            status: VisitorActionStatus.success, result: result));
      });

  Future<void> checkIn(String code, int guestCount) => _run(() async {
        final record = await _repository.checkInCode(code, guestCount);
        emit(VisitorActionState(
            status: VisitorActionStatus.success, record: record));
      });

  Future<void> checkOut(String visitId) => _run(() async {
        final record = await _repository.checkOut(visitId);
        emit(VisitorActionState(
            status: VisitorActionStatus.success, record: record));
      });

  void reset() => emit(const VisitorActionState());

  Future<void> _run(Future<void> Function() action) async {
    if (state.busy) return;
    emit(const VisitorActionState(status: VisitorActionStatus.busy));
    try {
      await action();
    } on GateApiException catch (error) {
      if (!isClosed) {
        emit(VisitorActionState(
          status: VisitorActionStatus.failure,
          message: error.message,
        ));
      }
    } catch (_) {
      if (!isClosed) {
        emit(const VisitorActionState(
          status: VisitorActionStatus.failure,
          message: 'Terjadi kesalahan, silakan coba lagi.',
        ));
      }
    }
  }
}
