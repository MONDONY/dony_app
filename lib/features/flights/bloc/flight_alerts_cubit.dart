import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/flights/bloc/flight_alert_updates.dart';
import 'package:dony/features/flights/bloc/flight_alerts_summary.dart';
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

  /// Résumé de la ligne « Alertes prix vols » des Outils d'Activités.
  FlightAlertsSummary get summary => FlightAlertsSummary.of(alerts);

  @override
  List<Object?> get props => [status, alerts, error, creating];
}

/// Alertes prix de l'écran `/flights/alerts`, de la feuille de création et
/// de la ligne « Alertes prix vols » des Outils d'Activités.
class FlightAlertsCubit extends Cubit<FlightAlertsState> {
  FlightAlertsCubit(
    this._repository,
    this._analytics, {
    FlightAlertUpdates? updates,
  }) : super(const FlightAlertsState()) {
    _updates = updates?.stream.listen(_applyUpdate);
  }

  final FlightsRepository _repository;
  final AnalyticsService _analytics;
  StreamSubscription<FlightAlert>? _updates;

  /// Alerte modifiée ailleurs (pause depuis les Paramètres) : remplacée dans
  /// la liste si elle y figure.
  void _applyUpdate(FlightAlert updated) {
    if (isClosed || !state.alerts.any((a) => a.id == updated.id)) return;
    emit(
      state.copyWith(
        alerts: [
          for (final a in state.alerts) a.id == updated.id ? updated : a,
        ],
      ),
    );
  }

  @override
  Future<void> close() async {
    await _updates?.cancel();
    return super.close();
  }

  /// Limite côté back (`FlightAlertService.MAX_ALERTS`).
  static const maxAlerts = 10;

  /// [silent] : rechargement d'une liste déjà affichée (retour sur l'onglet,
  /// tirer pour rafraîchir) ; l'état de chargement n'est pas émis, la ligne
  /// des Outils ne clignote pas.
  Future<void> load({bool silent = false}) async {
    if (!silent || state.status != FlightAlertsStatus.loaded) {
      emit(state.copyWith(status: FlightAlertsStatus.loading));
    }
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

  /// Ligne « Alertes prix vols » des Outils d'Activités touchée, avec l'état
  /// qu'elle montrait (`hit`, `no_hit` ou `empty`). Ni trajet ni prix.
  void trackHubOpened() => unawaited(
    _analytics.logEvent(
      AnalyticsEvents.activitesHubFlightAlertsOpened,
      properties: {'state': state.summary.kind.analyticsValue},
    ),
  );

  /// Rend `true` si l'alerte est créée. [source] : `results` (bannière des
  /// résultats), `alerts` (bouton de l'écran des alertes) ou `hub` (billet
  /// « Créer » de la ligne des Outils d'Activités).
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
    final previous = state.alerts.where((a) => a.id == id).firstOrNull;
    if (previous == null) return;
    emit(
      state.copyWith(
        alerts: [
          for (final a in state.alerts)
            a.id == id ? a.copyWith(active: active) : a,
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
      // Seule cette alerte est rétablie : une autre action menée pendant
      // l'appel garde son effet.
      emit(
        state.copyWith(
          alerts: [for (final a in state.alerts) a.id == id ? previous : a],
          error: unwrapDioError(err),
        ),
      );
    }
  }

  Future<void> delete(String id) async {
    final index = state.alerts.indexWhere((a) => a.id == id);
    if (index < 0) return;
    final removed = state.alerts[index];
    emit(state.copyWith(alerts: [...state.alerts]..removeAt(index)));
    try {
      await _repository.deleteAlert(id);
      unawaited(_analytics.logEvent(AnalyticsEvents.flightsAlertDeleted));
    } catch (err) {
      if (isClosed) return;
      // Remise à sa place, sans écraser ce qui a changé entre-temps.
      final alerts = [...state.alerts];
      alerts.insert(index.clamp(0, alerts.length), removed);
      emit(state.copyWith(alerts: alerts, error: unwrapDioError(err)));
    }
  }
}
