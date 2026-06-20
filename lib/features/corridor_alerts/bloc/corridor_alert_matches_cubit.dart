import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/corridor_alerts/data/corridor_alert_repository.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_matches.dart';
import 'package:equatable/equatable.dart';

enum CorridorAlertMatchesStatus { initial, loading, loaded, empty, error }

class CorridorAlertMatchesState extends Equatable {
  const CorridorAlertMatchesState({
    this.status = CorridorAlertMatchesStatus.initial,
    this.matches = const CorridorAlertMatches(
      direction: AlertDirection.travelerWantsPackages,
    ),
    this.errorMessage,
  });

  final CorridorAlertMatchesStatus status;
  final CorridorAlertMatches matches;
  final String? errorMessage;

  CorridorAlertMatchesState copyWith({
    CorridorAlertMatchesStatus? status,
    CorridorAlertMatches? matches,
    String? errorMessage,
  }) =>
      CorridorAlertMatchesState(
        status: status ?? this.status,
        matches: matches ?? this.matches,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [status, matches, errorMessage];
}

class CorridorAlertMatchesCubit extends Cubit<CorridorAlertMatchesState> {
  CorridorAlertMatchesCubit(
    this._repository,
    this._analytics, {
    required this.alertId,
    this.direction = AlertDirection.travelerWantsPackages,
  }) : super(const CorridorAlertMatchesState());

  final CorridorAlertRepository _repository;
  final AnalyticsService _analytics;
  final String alertId;
  final AlertDirection direction;

  Future<void> load() async {
    emit(state.copyWith(status: CorridorAlertMatchesStatus.loading));
    try {
      final matches = await _repository.getMatches(alertId, direction);
      if (matches.isEmpty) {
        emit(state.copyWith(
          status: CorridorAlertMatchesStatus.empty,
          matches: CorridorAlertMatches(direction: direction),
        ));
      } else {
        emit(state.copyWith(
          status: CorridorAlertMatchesStatus.loaded,
          matches: matches,
        ));
        unawaited(_analytics.logEvent(
          AnalyticsEvents.corridorAlertMatchesViewed,
          properties: {'count': matches.length},
        ));
      }
    } catch (err) {
      emit(state.copyWith(
        status: CorridorAlertMatchesStatus.error,
        errorMessage: err.toString(),
      ));
    }
  }
}
