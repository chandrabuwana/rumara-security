import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/gate_response.dart';
import '../../data/visitor_gate_models.dart';
import '../../data/visitor_gate_repository.dart';

class VisitorHomeState {
  const VisitorHomeState({
    this.loading = true,
    this.error,
    this.forbidden = false,
    this.summary = const VisitorSummary(),
    this.inside = const [],
  });

  final bool loading;
  final String? error;
  final bool forbidden;
  final VisitorSummary summary;
  final List<VisitorGateItem> inside;

  VisitorHomeState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    bool? forbidden,
    VisitorSummary? summary,
    List<VisitorGateItem>? inside,
  }) {
    return VisitorHomeState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      forbidden: forbidden ?? this.forbidden,
      summary: summary ?? this.summary,
      inside: inside ?? this.inside,
    );
  }
}

class VisitorHomeCubit extends Cubit<VisitorHomeState> {
  VisitorHomeCubit(this._repository) : super(const VisitorHomeState());

  final VisitorGateRepository _repository;
  Timer? _timer;

  Future<void> load({bool silent = false}) async {
    if (!silent) emit(state.copyWith(loading: true, clearError: true));
    try {
      final results = await Future.wait([
        _repository.summary(),
        _repository.inside(),
      ]);
      if (isClosed) return;
      emit(state.copyWith(
        loading: false,
        clearError: true,
        forbidden: false,
        summary: results[0] as VisitorSummary,
        inside: results[1] as List<VisitorGateItem>,
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
        error: silent ? state.error : 'Data visitor gagal dimuat.',
      ));
    }
  }

  void startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => load(silent: true),
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
