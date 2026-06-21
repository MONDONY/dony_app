import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';
import '../data/models/matching_request.dart';
import '../data/package_request_repository.dart';

sealed class TripMatchingEvent extends Equatable {
  const TripMatchingEvent();
  @override
  List<Object?> get props => [];
}

class TripMatchingRequested extends TripMatchingEvent {
  const TripMatchingRequested();
}

class TripMatchingRefreshRequested extends TripMatchingEvent {
  const TripMatchingRefreshRequested();
}

/// Bascule la cloche « me notifier quand un colis matche un de mes trajets ».
class TripMatchingAlertToggled extends TripMatchingEvent {
  const TripMatchingAlertToggled(this.enabled);
  final bool enabled;
  @override
  List<Object?> get props => [enabled];
}

enum TripMatchingStatus { initial, loading, loaded, error }

class TripMatchingState extends Equatable {
  const TripMatchingState({
    this.status = TripMatchingStatus.initial,
    this.matches = const [],
    this.alertEnabled,
    this.errorMessage,
  });

  final TripMatchingStatus status;
  final List<MatchingRequestModel> matches;

  /// État de la cloche (null tant que non chargé → cloche désactivée/loading).
  final bool? alertEnabled;
  final String? errorMessage;

  TripMatchingState copyWith({
    TripMatchingStatus? status,
    List<MatchingRequestModel>? matches,
    bool? alertEnabled,
    String? errorMessage,
  }) =>
      TripMatchingState(
        status: status ?? this.status,
        matches: matches ?? this.matches,
        alertEnabled: alertEnabled ?? this.alertEnabled,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [status, matches, alertEnabled, errorMessage];
}

class TripMatchingBloc extends Bloc<TripMatchingEvent, TripMatchingState> {
  TripMatchingBloc(this._repository, this._analytics)
      : super(const TripMatchingState()) {
    on<TripMatchingRequested>(_onLoad);
    on<TripMatchingRefreshRequested>(_onLoad);
    on<TripMatchingAlertToggled>(_onToggleAlert);
  }

  final PackageRequestRepository _repository;
  final AnalyticsService _analytics;

  Future<void> _onLoad(
      TripMatchingEvent e, Emitter<TripMatchingState> emit) async {
    emit(state.copyWith(status: TripMatchingStatus.loading));
    try {
      final matches = await _repository.findMatchingRequests();
      // L'état de la cloche est secondaire : un échec ne casse pas la liste.
      bool? alertEnabled = state.alertEnabled;
      try {
        alertEnabled = await _repository.getPackageMatchAlert();
      } catch (_) {
        // garde la valeur précédente (ou null)
      }
      emit(state.copyWith(
        status: TripMatchingStatus.loaded,
        matches: matches,
        alertEnabled: alertEnabled,
      ));
      unawaited(_analytics.logEvent(
        AnalyticsEvents.tripMatchingViewed,
        properties: {'count': matches.length},
      ));
    } catch (err) {
      emit(state.copyWith(
        status: TripMatchingStatus.error,
        errorMessage: err.toString(),
      ));
    }
  }

  Future<void> _onToggleAlert(
      TripMatchingAlertToggled e, Emitter<TripMatchingState> emit) async {
    final previous = state.alertEnabled;
    // Optimiste : on bascule l'UI tout de suite, on revient en arrière si l'API échoue.
    emit(state.copyWith(alertEnabled: e.enabled));
    try {
      await _repository.setPackageMatchAlert(e.enabled);
      unawaited(_analytics.logEvent(
        AnalyticsEvents.packageMatchAlertToggled,
        properties: {'enabled': e.enabled},
      ));
    } catch (_) {
      emit(state.copyWith(alertEnabled: previous));
    }
  }
}
