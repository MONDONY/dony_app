import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CancellationBloc extends Bloc<CancellationEvent, CancellationState> {
  final CancellationRepository _repository;

  CancellationBloc(this._repository) : super(CancellationInitial()) {
    on<CancellationTripRequested>(_onTripCancellationRequested);
    on<RematchSuggestionsRequested>(_onRematchRequested);
  }

  Future<void> _onTripCancellationRequested(
    CancellationTripRequested event,
    Emitter<CancellationState> emit,
  ) async {
    emit(CancellationLoading());
    try {
      final result = await _repository.cancelTrip(
        announcementId: event.announcementId,
        reason: event.reason,
      );
      emit(CancellationSuccess(result));
    } catch (e) {
      emit(CancellationError(unwrapDioError(e)));
    }
  }

  Future<void> _onRematchRequested(
    RematchSuggestionsRequested event,
    Emitter<CancellationState> emit,
  ) async {
    emit(CancellationLoading());
    try {
      final suggestions = await _repository.getRematchSuggestions(event.cancellationId);
      emit(RematchSuggestionsLoaded(suggestions));
    } catch (e) {
      emit(CancellationError(unwrapDioError(e)));
    }
  }
}
