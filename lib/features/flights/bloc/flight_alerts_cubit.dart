import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/data/repositories/flights_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum FlightAlertsStatus { initial, loading, loaded, error }

class FlightAlertsState extends Equatable {
  const FlightAlertsState({
    this.status = FlightAlertsStatus.initial,
    this.alerts = const [],
    this.error,
    this.creating = false,
  });

  final FlightAlertsStatus status;
  final List<FlightAlert> alerts;

  /// Dernière erreur : de chargement si la liste est vide, sinon d'une action
  /// (bascule, suppression, création) à montrer en snackbar.
  final AppException? error;
  final bool creating;

  FlightAlertsState copyWith({
    FlightAlertsStatus? status,
    List<FlightAlert>? alerts,
    AppException? error,
    bool? creating,
  }) => FlightAlertsState(
    status: status ?? this.status,
    alerts: alerts ?? this.alerts,
    error: error,
    creating: creating ?? this.creating,
  );

  @override
  List<Object?> get props => [status, alerts, error, creating];
}

/// Alertes prix de l'écran `/flights/alerts` et de la feuille de création.
class FlightAlertsCubit extends Cubit<FlightAlertsState> {
  FlightAlertsCubit(this._repository, this._analytics)
    : super(const FlightAlertsState());

  final FlightsRepository _repository;
  final AnalyticsService _analytics;

  /// Limite côté back (`FlightAlertService.MAX_ALERTS`).
  static const maxAlerts = 10;

  Future<void> load() async {
    emit(state.copyWith(status: FlightAlertsStatus.loading));
    try {
      final alerts = await _repository.alerts();
      if (isClosed) return;
      emit(state.copyWith(status: FlightAlertsStatus.loaded, alerts: alerts));
    } catch (err) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: FlightAlertsStatus.error,
          error: unwrapDioError(err),
        ),
      );
    }
  }

  /// Rend `true` si l'alerte est créée. [source] : `results` (bannière des
  /// résultats) ou `alerts` (bouton de l'écran des alertes).
  Future<bool> create(FlightAlertDraft draft, {required String source}) async {
    emit(state.copyWith(creating: true));
    try {
      final created = await _repository.createAlert(draft);
      if (isClosed) return true;
      emit(
        state.copyWith(
          creating: false,
          status: FlightAlertsStatus.loaded,
          alerts: [created, ...state.alerts],
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.flightsAlertCreated,
          properties: {
            'round_trip': draft.returnFrom != null,
            'has_period': draft.departureFrom != null,
            'direct_only': draft.directOnly,
            'source': source,
          },
        ),
      );
      return true;
    } catch (err) {
      if (!isClosed) {
        emit(state.copyWith(creating: false, error: unwrapDioError(err)));
      }
      return false;
    }
  }

  Future<void> setActive(String id, bool active) async {
    final previous = state.alerts;
    emit(
      state.copyWith(
        alerts: [
          for (final a in previous) a.id == id ? a.copyWith(active: active) : a,
        ],
      ),
    );
    try {
      final updated = await _repository.setAlertActive(id, active);
      if (isClosed) return;
      emit(
        state.copyWith(
          alerts: [for (final a in state.alerts) a.id == id ? updated : a],
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.flightsAlertToggled,
          properties: {'active': active},
        ),
      );
    } catch (err) {
      if (isClosed) return;
      emit(state.copyWith(alerts: previous, error: unwrapDioError(err)));
    }
  }

  Future<void> delete(String id) async {
    final previous = state.alerts;
    emit(state.copyWith(alerts: previous.where((a) => a.id != id).toList()));
    try {
      await _repository.deleteAlert(id);
      unawaited(_analytics.logEvent(AnalyticsEvents.flightsAlertDeleted));
    } catch (err) {
      if (isClosed) return;
      emit(state.copyWith(alerts: previous, error: unwrapDioError(err)));
    }
  }
}
