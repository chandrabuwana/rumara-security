import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../visitor_gate/data/gate_response.dart';
import '../../data/info_create_repository.dart';

class InfoCreateState {
  const InfoCreateState({
    this.loadingCategories = true,
    this.categories = const [],
    this.submitting = false,
    this.done = false,
    this.error,
  });

  final bool loadingCategories;
  final List<InfoCategory> categories;
  final bool submitting;
  final bool done;
  final String? error;

  InfoCreateState copyWith({
    bool? loadingCategories,
    List<InfoCategory>? categories,
    bool? submitting,
    bool? done,
    String? error,
    bool clearError = false,
  }) {
    return InfoCreateState(
      loadingCategories: loadingCategories ?? this.loadingCategories,
      categories: categories ?? this.categories,
      submitting: submitting ?? this.submitting,
      done: done ?? this.done,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class InfoCreateCubit extends Cubit<InfoCreateState> {
  InfoCreateCubit(this._repository) : super(const InfoCreateState());

  final InfoCreateRepository _repository;

  Future<void> loadCategories() async {
    emit(state.copyWith(loadingCategories: true, clearError: true));
    try {
      final categories = await _repository.categories();
      if (!isClosed) {
        emit(state.copyWith(loadingCategories: false, categories: categories));
      }
    } on GateApiException catch (error) {
      if (!isClosed) {
        emit(state.copyWith(loadingCategories: false, error: error.message));
      }
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(
          loadingCategories: false,
          error: 'Kategori informasi gagal dimuat.',
        ));
      }
    }
  }

  Future<void> submit(InfoDraft draft) async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      await _repository.submit(draft);
      if (!isClosed) emit(state.copyWith(submitting: false, done: true));
    } on GateApiException catch (error) {
      if (!isClosed) {
        emit(state.copyWith(submitting: false, error: error.message));
      }
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(
          submitting: false,
          error: 'Informasi gagal dikirim, silakan coba lagi.',
        ));
      }
    }
  }
}
