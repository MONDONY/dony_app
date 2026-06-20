import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/corridor_alerts/data/corridor_alert_repository.dart';
import 'package:dony/features/package_request/data/models/matching_request.dart';
import 'package:equatable/equatable.dart';

enum CorridorAlertMatchesStatus { initial, loading, loaded, empty, error }

class CorridorAlertMatchesState extends Equatable {
  const CorridorAlertMatchesState({
    this.status = CorridorAlertMatchesStatus.initial,
    this.matches = const [],
    this.errorMessage,
  });

  final CorridorAlertMatchesStatus status;
  final List<MatchingRequestModel> matches;
  final String? errorMessage;

  CorridorAlertMatchesState copyWith({
    CorridorAlertMatchesStatus? status,
    List<MatchingRequestModel>? matches,
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
  }) : super(const CorridorAlertMatchesState());

  final CorridorAlertRepository _repository;
  final AnalyticsService _analytics;
  final String alertId;

  Future<void> load() async {
    emit(state.copyWith(status: CorridorAlertMatchesStatus.loading));
    try {
      final matches = await _repository.getMatches(alertId);
      if (matches.isEmpty) {
        emit(state.copyWith(
          status: CorridorAlertMatchesStatus.empty,
          matches: const [],
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
