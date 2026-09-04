import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/corridor_alerts/data/corridor_alert_repository.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_matches.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum CorridorAlertMatchesStatus { initial, loading, loaded, empty, error }

class CorridorAlertMatchesState extends Equatable {
  const CorridorAlertMatchesState({
    this.status = CorridorAlertMatchesStatus.initial,
    this.alert,
    this.result,
    this.errorMessage,
    this.seenThreshold,
    this.thresholdKnown = false,
  });

  final CorridorAlertMatchesStatus status;

  /// L'alerte dont on liste les correspondances. Fournie par l'écran liste,
  /// ou chargée par son id quand on arrive d'un push.
  final CorridorAlertModel? alert;
  final CorridorAlertMatches? result;
  final String? errorMessage;

  /// Dernière consultation AVANT cette ouverture : c'est elle qui sépare
  /// « nouveaux » et « déjà vus ». Figée au chargement, elle ne bouge pas
  /// quand l'alerte est marquée vue dans la foulée, sinon tout deviendrait
  /// « déjà vu » à l'instant où l'écran s'affiche.
  final DateTime? seenThreshold;

  /// Vrai une fois le seuil lu depuis l'alerte (`null` = jamais consultée).
  final bool thresholdKnown;

  /// Un élément est nouveau s'il est apparu après la dernière consultation,
  /// ou si l'alerte n'a jamais été consultée. Sans horodatage, on le range
  /// dans les « déjà vus » plutôt que de crier au nouveau à tort.
  bool isNew(DateTime? createdAt) {
    if (!thresholdKnown) return false;
    if (seenThreshold == null) return true;
    return createdAt != null && createdAt.isAfter(seenThreshold!);
  }

  CorridorAlertMatchesState copyWith({
    CorridorAlertMatchesStatus? status,
    CorridorAlertModel? alert,
    CorridorAlertMatches? result,
    String? errorMessage,
    DateTime? seenThreshold,
    bool? thresholdKnown,
  }) => CorridorAlertMatchesState(
    status: status ?? this.status,
    alert: alert ?? this.alert,
    result: result ?? this.result,
    errorMessage: errorMessage ?? this.errorMessage,
    seenThreshold: seenThreshold ?? this.seenThreshold,
    thresholdKnown: thresholdKnown ?? this.thresholdKnown,
  );

  @override
  List<Object?> get props => [
    status,
    alert,
    result,
    errorMessage,
    seenThreshold,
    thresholdKnown,
  ];
}

class CorridorAlertMatchesCubit extends Cubit<CorridorAlertMatchesState> {
  CorridorAlertMatchesCubit(
    this._repository,
    this._analytics, {
    required this.alertId,
    CorridorAlertModel? alert,
  }) : super(CorridorAlertMatchesState(alert: alert));

  final CorridorAlertRepository _repository;
  final AnalyticsService _analytics;
  final String alertId;

  Future<void> load() async {
    emit(state.copyWith(status: CorridorAlertMatchesStatus.loading));
    try {
      final alert = state.alert ?? await _repository.getById(alertId);
      final direction = alert.direction;
      // Le seuil se lit une seule fois : un rechargement (Réessayer) après
      // « vu » ne doit pas faire disparaître les nouveautés.
      final threshold = state.thresholdKnown
          ? state.seenThreshold
          : alert.lastSeenAt;
      final matches = await _repository.getMatches(alertId, direction);
      if (matches.isEmpty) {
        emit(
          state.copyWith(
            status: CorridorAlertMatchesStatus.empty,
            alert: alert,
            result: CorridorAlertMatches(direction: direction),
            seenThreshold: threshold,
            thresholdKnown: true,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: CorridorAlertMatchesStatus.loaded,
            alert: alert,
            result: matches,
            seenThreshold: threshold,
            thresholdKnown: true,
          ),
        );
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.corridorAlertMatchesViewed,
            properties: {'count': matches.length},
          ),
        );
      }
      // L'utilisateur a les correspondances sous les yeux : tout ce qui est
      // là est vu. Un échec ici ne doit pas casser l'écran, la pastille
      // s'éteindra à la prochaine ouverture.
      unawaited(_markSeen());
    } catch (err) {
      emit(
        state.copyWith(
          status: CorridorAlertMatchesStatus.error,
          errorMessage: err.toString(),
        ),
      );
    }
  }

  Future<void> _markSeen() async {
    try {
      final seen = await _repository.markSeen(alertId);
      if (!isClosed) emit(state.copyWith(alert: seen));
    } catch (_) {
      // Silencieux : voir ci-dessus.
    }
  }
}
