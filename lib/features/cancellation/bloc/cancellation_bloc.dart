import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CancellationBloc extends Bloc<CancellationEvent, CancellationState> {
  final CancellationRepository _repository;
  final AnalyticsService _analytics;

  CancellationBloc(this._repository, this._analytics) : super(CancellationInitial()) {
    on<CancellationTripRequested>(_onTripCancellationRequested);
    on<RematchSuggestionsRequested>(_onRematchRequested);
    on<NoShowReportRequested>(_onNoShowReport);
    on<NoShowContestRequested>(_onNoShowContest);
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
      unawaited(_analytics.logEvent(
        AnalyticsEvents.cancellationInitiated,
        properties: {'reason': event.reason},
      ));
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

  Future<void> _onNoShowReport(
    NoShowReportRequested event,
    Emitter<CancellationState> emit,
  ) async {
    emit(CancellationLoading());
    try {
      await _repository.reportNoShow(event.bidId);
      emit(NoShowReported());
    } catch (e) {
      emit(CancellationError(unwrapDioError(e)));
    }
  }

  Future<void> _onNoShowContest(
    NoShowContestRequested event,
    Emitter<CancellationState> emit,
  ) async {
    emit(CancellationLoading());
    try {
      await _repository.contestNoShow(event.bidId);
      emit(NoShowContested());
    } catch (e) {
      emit(CancellationError(unwrapDioError(e)));
    }
  }
}
