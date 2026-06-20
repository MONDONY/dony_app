import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';
import '../data/corridor_alert_repository.dart';
import '../data/models/corridor_alert_model.dart';

sealed class CorridorAlertListEvent extends Equatable {
  const CorridorAlertListEvent();
  @override
  List<Object?> get props => [];
}

class CorridorAlertListRequested extends CorridorAlertListEvent {}

class CorridorAlertActiveToggled extends CorridorAlertListEvent {
  const CorridorAlertActiveToggled(this.id, this.active);
  final String id;
  final bool active;
  @override
  List<Object?> get props => [id, active];
}

class CorridorAlertDeleted extends CorridorAlertListEvent {
  const CorridorAlertDeleted(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

enum CorridorAlertListStatus { initial, loading, loaded, error }

class CorridorAlertListState extends Equatable {
  const CorridorAlertListState({
    this.status = CorridorAlertListStatus.initial,
    this.alerts = const [],
    this.errorMessage,
  });

  final CorridorAlertListStatus status;
  final List<CorridorAlertModel> alerts;
  final String? errorMessage;

  CorridorAlertListState copyWith({
    CorridorAlertListStatus? status,
    List<CorridorAlertModel>? alerts,
    String? errorMessage,
  }) =>
      CorridorAlertListState(
        status: status ?? this.status,
        alerts: alerts ?? this.alerts,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [status, alerts, errorMessage];
}

class CorridorAlertListBloc
    extends Bloc<CorridorAlertListEvent, CorridorAlertListState> {
  CorridorAlertListBloc(this._repository, this._analytics)
      : super(const CorridorAlertListState()) {
    on<CorridorAlertListRequested>(_onLoad);
    on<CorridorAlertActiveToggled>(_onToggle);
    on<CorridorAlertDeleted>(_onDelete);
  }

  final CorridorAlertRepository _repository;
  final AnalyticsService _analytics;

  Future<void> _onLoad(
      CorridorAlertListRequested e,
      Emitter<CorridorAlertListState> emit) async {
    emit(state.copyWith(status: CorridorAlertListStatus.loading));
    try {
      final alerts = await _repository.getMyAlerts();
      emit(state.copyWith(
        status: CorridorAlertListStatus.loaded,
        alerts: alerts,
      ));
    } catch (err) {
      emit(state.copyWith(
        status: CorridorAlertListStatus.error,
        errorMessage: err.toString(),
      ));
    }
  }

  Future<void> _onToggle(
      CorridorAlertActiveToggled e,
      Emitter<CorridorAlertListState> emit) async {
    final previous = state.alerts;
    final target = previous.firstWhere((a) => a.id == e.id);
    // Optimistic: flip active immediately.
    emit(state.copyWith(
      alerts: previous
          .map((a) => a.id == e.id ? a.copyWith(active: e.active) : a)
          .toList(),
    ));
    try {
      final updated = await _repository.update(
        e.id,
        CorridorAlertDraft(
          departureCity: target.departureCity,
          arrivalCity: target.arrivalCity,
          departureCountryCode: target.departureCountryCode,
          arrivalCountryCode: target.arrivalCountryCode,
          dateFrom: target.dateFrom,
          dateTo: target.dateTo,
          minWeightKg: target.minWeightKg,
          contentCategories: target.contentCategories,
        ),
      );
      // Reconcile with server truth only when matchCount changed.
      final currentTarget = state.alerts.firstWhere((a) => a.id == e.id);
      if (currentTarget.matchCount != updated.matchCount) {
        emit(state.copyWith(
          alerts: state.alerts
              .map((a) => a.id == e.id
                  ? a.copyWith(
                      active: updated.active, matchCount: updated.matchCount)
                  : a)
              .toList(),
        ));
      }
      unawaited(_analytics.logEvent(
        AnalyticsEvents.corridorAlertToggled,
        properties: {'active': e.active},
      ));
    } catch (err) {
      // Rollback to previous list.
      emit(state.copyWith(
        status: CorridorAlertListStatus.error,
        alerts: previous,
        errorMessage: err.toString(),
      ));
    }
  }

  Future<void> _onDelete(
      CorridorAlertDeleted e,
      Emitter<CorridorAlertListState> emit) async {
    final previous = state.alerts;
    // Optimistic: remove immediately.
    emit(state.copyWith(
      alerts: previous.where((a) => a.id != e.id).toList(),
    ));
    try {
      await _repository.delete(e.id);
      unawaited(_analytics.logEvent(AnalyticsEvents.corridorAlertDeleted));
    } catch (err) {
      emit(state.copyWith(
        status: CorridorAlertListStatus.error,
        alerts: previous,
        errorMessage: err.toString(),
      ));
    }
  }
}
