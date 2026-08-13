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

  CancellationBloc(this._repository, this._analytics)
    : super(CancellationInitial()) {
    on<CancellationTripRequested>(_onTripCancellationRequested);
    on<RematchSuggestionsRequested>(_onRematchRequested);
    on<NoShowReportRequested>(_onNoShowReport);
    on<TravelerNoShowReportRequested>(_onTravelerNoShowReport);
    on<NoShowContestRequested>(_onNoShowContest);
    on<DeliveryNoShowReportRequested>(_onDeliveryNoShowReport);
    on<TravelerDeliveryNoShowReportRequested>(_onTravelerDeliveryNoShowReport);
    on<DeliveryNoShowContestRequested>(_onDeliveryNoShowContest);
    on<NoShowConfirmRequested>(_onNoShowConfirm);
    on<CancelAfterHandoverRequested>(_onCancelAfterHandover);
    on<ReturnConfirmRequested>(_onReturnConfirm);
    on<ReturnCodeRequested>(_onReturnCodeRequested);
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
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.cancellationInitiated,
          properties: {'reason': event.reason},
        ),
      );
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
      final suggestions = await _repository.getRematchSuggestions(
        event.cancellationId,
      );
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
      unawaited(_analytics.logEvent(AnalyticsEvents.noShowReportedByTraveler));
    } catch (e) {
      emit(CancellationError(unwrapDioError(e)));
    }
  }

  Future<void> _onTravelerNoShowReport(
    TravelerNoShowReportRequested event,
    Emitter<CancellationState> emit,
  ) async {
    emit(CancellationLoading());
    try {
      await _repository.reportTravelerNoShow(event.bidId);
      emit(NoShowReported());
      unawaited(_analytics.logEvent(AnalyticsEvents.noShowReportedBySender));
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

  Future<void> _onDeliveryNoShowReport(
    DeliveryNoShowReportRequested event,
    Emitter<CancellationState> emit,
  ) async {
    emit(CancellationLoading());
    try {
      await _repository.reportDeliveryNoShow(event.bidId);
      emit(DeliveryNoShowReported());
      unawaited(
        _analytics.logEvent(AnalyticsEvents.deliveryNoShowReportedByTraveler),
      );
    } catch (e) {
      emit(CancellationError(unwrapDioError(e)));
    }
  }

  Future<void> _onTravelerDeliveryNoShowReport(
    TravelerDeliveryNoShowReportRequested event,
    Emitter<CancellationState> emit,
  ) async {
    emit(CancellationLoading());
    try {
      await _repository.reportTravelerDeliveryNoShow(event.bidId);
      emit(DeliveryNoShowReported());
      unawaited(
        _analytics.logEvent(AnalyticsEvents.deliveryNoShowReportedBySender),
      );
    } catch (e) {
      emit(CancellationError(unwrapDioError(e)));
    }
  }

  Future<void> _onDeliveryNoShowContest(
    DeliveryNoShowContestRequested event,
    Emitter<CancellationState> emit,
  ) async {
    emit(CancellationLoading());
    try {
      await _repository.contestDeliveryNoShow(event.bidId);
      emit(DeliveryNoShowContested());
      unawaited(_analytics.logEvent(AnalyticsEvents.deliveryNoShowContested));
    } catch (e) {
      emit(CancellationError(unwrapDioError(e)));
    }
  }

  Future<void> _onNoShowConfirm(
    NoShowConfirmRequested event,
    Emitter<CancellationState> emit,
  ) async {
    emit(CancellationLoading());
    try {
      await _repository.confirmNoShow(event.bidId);
      emit(NoShowConfirmed());
    } catch (e) {
      emit(CancellationError(unwrapDioError(e)));
    }
  }

  Future<void> _onCancelAfterHandover(
    CancelAfterHandoverRequested event,
    Emitter<CancellationState> emit,
  ) async {
    emit(CancellationLoading());
    try {
      await _repository.cancelAfterHandover(event.bidId);
      emit(CancelledAfterHandover());
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.cancelAfterHandoverInitiated,
          properties: {'actor': event.actor},
        ),
      );
    } catch (e) {
      emit(CancellationError(unwrapDioError(e)));
    }
  }

  Future<void> _onReturnConfirm(
    ReturnConfirmRequested event,
    Emitter<CancellationState> emit,
  ) async {
    emit(CancellationLoading());
    try {
      final result = await _repository.confirmReturn(event.bidId, event.code);
      emit(ReturnConfirmed(result));
      unawaited(_analytics.logEvent(AnalyticsEvents.returnConfirmed));
    } catch (e) {
      emit(CancellationError(unwrapDioError(e)));
    }
  }

  Future<void> _onReturnCodeRequested(
    ReturnCodeRequested event,
    Emitter<CancellationState> emit,
  ) async {
    emit(CancellationLoading());
    try {
      final result = await _repository.getReturnCode(event.bidId);
      emit(ReturnCodeLoaded(result));
      unawaited(_analytics.logEvent(AnalyticsEvents.returnCodeViewed));
    } catch (e) {
      emit(CancellationError(unwrapDioError(e)));
    }
  }
}
