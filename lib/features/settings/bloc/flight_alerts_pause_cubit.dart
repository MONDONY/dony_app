import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/flights/bloc/flight_alert_updates.dart';
import 'package:dony/features/flights/data/repositories/flights_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum FlightAlertsPausePhase {
  /// Rien à proposer.
  idle,

  /// Lecture des alertes après le masquage des billets.
  checking,

  /// Des alertes sont actives : la feuille propose de les mettre en pause.
  prompt,

  /// Mise en pause en cours (bouton principal en chargement).
  pausing,

  /// Mise en pause terminée : [FlightAlertsPauseState.paused] réussies,
  /// [FlightAlertsPauseState.failed] refusées.
  done,
}

class FlightAlertsPauseState extends Equatable {
  const FlightAlertsPauseState({
    this.phase = FlightAlertsPausePhase.idle,
    this.activeIds = const [],
    this.paused = 0,
    this.failed = 0,
  });

  final FlightAlertsPausePhase phase;

  /// Alertes actives au moment du masquage.
  final List<String> activeIds;
  final int paused;
  final int failed;

  int get activeCount => activeIds.length;

  @override
  List<Object?> get props => [phase, activeIds, paused, failed];
}

/// Masquer les billets (Paramètres › Apparence) ne coupe pas les
/// notifications des alertes prix, qui vivent côté serveur. Au masquage, ce
/// cubit lit les alertes et, s'il en trouve d'actives, propose de les mettre
/// en pause. Réafficher les billets ne relance rien.
class FlightAlertsPauseCubit extends Cubit<FlightAlertsPauseState> {
  FlightAlertsPauseCubit(
    this._repository,
    this._analytics, {
    FlightAlertUpdates? updates,
  }) : _updates = updates,
       super(const FlightAlertsPauseState());

  final FlightsRepository _repository;
  final AnalyticsService _analytics;
  final FlightAlertUpdates? _updates;

  /// Appelé quand l'utilisateur coupe l'interrupteur. Sans alerte active, ou
  /// si la lecture échoue (hors ligne), rien n'est proposé : le masquage
  /// reste acquis.
  Future<void> onFlightsHidden() async {
    if (state.phase != FlightAlertsPausePhase.idle &&
        state.phase != FlightAlertsPausePhase.done) {
      return;
    }
    emit(const FlightAlertsPauseState(phase: FlightAlertsPausePhase.checking));
    try {
      final alerts = await _repository.alerts();
      if (isClosed) return;
      final active = [
        for (final a in alerts)
          if (a.active) a.id,
      ];
      emit(
        active.isEmpty
            ? const FlightAlertsPauseState()
            : FlightAlertsPauseState(
                phase: FlightAlertsPausePhase.prompt,
                activeIds: active,
              ),
      );
    } catch (err) {
      AppLog.warn(
        'flights: alerts read failed after hiding flights',
        data: {'error': err.runtimeType.toString()},
      );
      if (!isClosed) emit(const FlightAlertsPauseState());
    }
  }

  /// Les billets ont été réaffichés avant la fin de la lecture : la feuille
  /// n'a plus lieu d'être, sans réponse à mesurer.
  void cancel() {
    if (state.phase == FlightAlertsPausePhase.checking ||
        state.phase == FlightAlertsPausePhase.prompt) {
      emit(const FlightAlertsPauseState());
    }
  }

  /// « Mettre en pause » : coupe chaque alerte active. Les alertes refusées
  /// restent actives, l'utilisateur peut réessayer depuis « Mes alertes ».
  Future<void> pause() async {
    if (state.phase != FlightAlertsPausePhase.prompt) return;
    final ids = state.activeIds;
    _trackChoice('pause');
    emit(
      FlightAlertsPauseState(
        phase: FlightAlertsPausePhase.pausing,
        activeIds: ids,
      ),
    );
    final results = await Future.wait(ids.map(_pauseOne));
    final paused = results.where((ok) => ok).length;
    final failed = results.length - paused;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.settingsFlightsAlertsPaused,
        properties: {'count': paused, 'failed': failed},
      ),
    );
    if (isClosed) return;
    emit(
      FlightAlertsPauseState(
        phase: FlightAlertsPausePhase.done,
        activeIds: ids,
        paused: paused,
        failed: failed,
      ),
    );
  }

  Future<bool> _pauseOne(String id) async {
    try {
      final updated = await _repository.setAlertActive(id, false);
      _updates?.publish(updated);
      return true;
    } catch (err) {
      AppLog.warn(
        'flights: alert pause failed',
        data: {'error': err.runtimeType.toString()},
      );
      return false;
    }
  }

  /// « Garder les alertes ».
  void keep() => _close('keep');

  /// Feuille fermée par geste : les alertes sont gardées.
  void dismiss() => _close('dismiss');

  /// Résultat de la pause affiché.
  void acknowledge() {
    if (state.phase == FlightAlertsPausePhase.done) {
      emit(const FlightAlertsPauseState());
    }
  }

  void _close(String choice) {
    if (state.phase != FlightAlertsPausePhase.prompt) return;
    _trackChoice(choice);
    emit(const FlightAlertsPauseState());
  }

  void _trackChoice(String choice) => unawaited(
    _analytics.logEvent(
      AnalyticsEvents.settingsFlightsAlertsPausePrompt,
      properties: {'active_count': state.activeCount, 'choice': choice},
    ),
  );
}
