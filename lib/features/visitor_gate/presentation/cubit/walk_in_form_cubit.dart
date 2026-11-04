import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/gate_response.dart';
import '../../data/visitor_gate_models.dart';
import '../../data/visitor_gate_repository.dart';

class WalkInFormState {
  const WalkInFormState({
    this.loadingOptions = true,
    this.options = const VisitorGateOptions(),
    this.searching = false,
    this.units = const [],
    this.unit,
    this.submitting = false,
    this.error,
    this.ticket,
  });

  final bool loadingOptions;
  final VisitorGateOptions options;
  final bool searching;
  final List<VisitorUnitChoice> units;
  final VisitorUnitChoice? unit;
  final bool submitting;
  final String? error;
  final WalkInTicket? ticket;

  WalkInFormState copyWith({
    bool? loadingOptions,
    VisitorGateOptions? options,
    bool? searching,
    List<VisitorUnitChoice>? units,
    VisitorUnitChoice? unit,
    bool clearUnit = false,
    bool? submitting,
    String? error,
    bool clearError = false,
    WalkInTicket? ticket,
  }) {
    return WalkInFormState(
      loadingOptions: loadingOptions ?? this.loadingOptions,
      options: options ?? this.options,
      searching: searching ?? this.searching,
      units: units ?? this.units,
      unit: clearUnit ? null : (unit ?? this.unit),
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
      ticket: ticket,
    );
  }
}

class WalkInFormCubit extends Cubit<WalkInFormState> {
  WalkInFormCubit(this._repository) : super(const WalkInFormState());

  final VisitorGateRepository _repository;
  Timer? _debounce;
  int _searchToken = 0;

  Future<void> loadOptions() async {
    try {
      final options = await _repository.options();
      if (!isClosed)
        emit(state.copyWith(loadingOptions: false, options: options));
    } on GateApiException catch (error) {
      if (!isClosed)
        emit(state.copyWith(loadingOptions: false, error: error.message));
    } catch (_) {
      if (!isClosed) emit(state.copyWith(loadingOptions: false));
    }
  }

  void searchUnits(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      emit(state.copyWith(units: const [], searching: false));
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    final token = ++_searchToken;
    emit(state.copyWith(searching: true, clearError: true));
    try {
      final units = await _repository.units(query);
      if (isClosed || token != _searchToken) return;
      emit(state.copyWith(searching: false, units: units));
    } on GateApiException catch (error) {
      if (isClosed || token != _searchToken) return;
      emit(state.copyWith(searching: false, error: error.message));
    } catch (_) {
      if (isClosed || token != _searchToken) return;
      emit(state.copyWith(searching: false, error: 'Unit gagal dicari.'));
    }
  }

  void selectUnit(VisitorUnitChoice? unit) {
    emit(unit == null
        ? state.copyWith(clearUnit: true)
        : state.copyWith(unit: unit, units: const []));
  }

  Future<void> submit(WalkInDraft draft) async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final ticket = await _repository.createWalkIn(draft);
      if (isClosed) return;
      emit(state.copyWith(submitting: false, ticket: ticket));
    } on GateApiException catch (error) {
      if (!isClosed)
        emit(state.copyWith(submitting: false, error: error.message));
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(
          submitting: false,
          error: 'Permintaan gagal dikirim, silakan coba lagi.',
        ));
      }
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
