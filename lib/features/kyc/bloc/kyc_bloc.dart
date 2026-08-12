import 'dart:async';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/data/repositories/kyc_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class KycBloc extends Bloc<KycEvent, KycState> {
  final KycRepository _repository;
  final AnalyticsService _analytics;
  final ErrorReportingService? _errorReporter;

  KycBloc(this._repository, this._analytics, [this._errorReporter])
    : super(const KycInitial()) {
    on<KycSessionRequested>(_onSessionRequested);
    on<KycStatusRefreshed>(_onStatusRefreshed);
    on<KycReset>((_, emit) => emit(const KycInitial()));
    on<KycSessionAbandoned>(_onSessionAbandoned);
  }

  Future<void> _onSessionRequested(
    KycSessionRequested event,
    Emitter<KycState> emit,
  ) async {
    emit(const KycLoading());
    try {
      final data = await _repository.createSession();
      emit(
        KycSessionCreated(
          stripeUrl: data['stripeUrl'] as String,
          sessionId: data['sessionId'] as String,
        ),
      );
      unawaited(_analytics.logEvent(AnalyticsEvents.kycStarted));
    } catch (e, stackTrace) {
      if (e is! DioException) {
        unawaited(
          _errorReporter?.report(
            e,
            operation: 'kyc.create_session',
            stackTrace: stackTrace,
            context: {'feature': 'kyc'},
          ),
        );
      }
      emit(KycError(unwrapDioError(e)));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.kycFailed,
          properties: {'reason': e.toString()},
        ),
      );
    }
  }

  Future<void> _onStatusRefreshed(
    KycStatusRefreshed event,
    Emitter<KycState> emit,
  ) async {
    try {
      final data = await _repository.getStatus();
      emit(
        KycStatusLoaded(
          kycStatus: data['kycStatus'] as String,
          verificationStatus: data['verificationStatus'] as String,
          rejectionCode: data['rejectionCode'] as String?,
        ),
      );
      if ((data['kycStatus'] as String) == 'VERIFIED') {
        unawaited(_analytics.logEvent(AnalyticsEvents.kycCompleted));
      }
    } catch (e, stackTrace) {
      if (e is! DioException) {
        unawaited(
          _errorReporter?.report(
            e,
            operation: 'kyc.refresh_status',
            stackTrace: stackTrace,
            context: {'feature': 'kyc'},
          ),
        );
      }
      emit(KycError(unwrapDioError(e)));
    }
  }

  Future<void> _onSessionAbandoned(
    KycSessionAbandoned event,
    Emitter<KycState> emit,
  ) async {
    try {
      await _repository.abandonSession();
    } catch (error, stackTrace) {
      // Erreur silencieuse — l'utilisateur part quand même
      if (error is! DioException) {
        unawaited(
          _errorReporter?.report(
            error,
            operation: 'kyc.abandon_session',
            stackTrace: stackTrace,
            context: {'feature': 'kyc'},
          ),
        );
      }
    }
  }
}
