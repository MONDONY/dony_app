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

enum TripMatchingStatus { initial, loading, loaded, error }

class TripMatchingState extends Equatable {
  const TripMatchingState({
    this.status = TripMatchingStatus.initial,
    this.matches = const [],
    this.errorMessage,
  });

  final TripMatchingStatus status;
  final List<MatchingRequestModel> matches;
  final String? errorMessage;

  TripMatchingState copyWith({
    TripMatchingStatus? status,
    List<MatchingRequestModel>? matches,
    String? errorMessage,
  }) =>
      TripMatchingState(
        status: status ?? this.status,
        matches: matches ?? this.matches,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [status, matches, errorMessage];
}

class TripMatchingBloc extends Bloc<TripMatchingEvent, TripMatchingState> {
  TripMatchingBloc(this._repository, this._analytics)
      : super(const TripMatchingState()) {
    on<TripMatchingRequested>(_onLoad);
    on<TripMatchingRefreshRequested>(_onLoad);
  }

  final PackageRequestRepository _repository;
  final AnalyticsService _analytics;

  Future<void> _onLoad(
      TripMatchingEvent e, Emitter<TripMatchingState> emit) async {
    emit(state.copyWith(status: TripMatchingStatus.loading));
    try {
      final matches = await _repository.findMatchingRequests();
      emit(state.copyWith(
        status: TripMatchingStatus.loaded,
        matches: matches,
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
}
