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
  });

  final CorridorAlertMatchesStatus status;

  /// L'alerte dont on liste les correspondances. Fournie par l'écran liste,
  /// ou chargée par son id quand on arrive d'un push.
  final CorridorAlertModel? alert;
  final CorridorAlertMatches? result;
  final String? errorMessage;

  CorridorAlertMatchesState copyWith({
    CorridorAlertMatchesStatus? status,
    CorridorAlertModel? alert,
    CorridorAlertMatches? result,
    String? errorMessage,
  }) => CorridorAlertMatchesState(
    status: status ?? this.status,
    alert: alert ?? this.alert,
    result: result ?? this.result,
    errorMessage: errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => [status, alert, result, errorMessage];
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
      final matches = await _repository.getMatches(alertId, direction);
      if (matches.isEmpty) {
        emit(
          state.copyWith(
            status: CorridorAlertMatchesStatus.empty,
            alert: alert,
            result: CorridorAlertMatches(direction: direction),
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: CorridorAlertMatchesStatus.loaded,
            alert: alert,
            result: matches,
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
