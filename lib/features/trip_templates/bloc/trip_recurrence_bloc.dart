import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_state.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_recurrence_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TripRecurrenceBloc
    extends Bloc<TripRecurrenceEvent, TripRecurrenceState> {
  TripRecurrenceBloc(this._repository, {AnalyticsService? analytics})
    : _analytics = analytics,
      super(const TripRecurrenceState()) {
    on<TripRecurrenceLoaded>(_onLoaded);
    on<TripRecurrenceCreated>(_onCreated);
    on<TripRecurrenceUpdated>(_onUpdated);
    on<TripRecurrenceDeleted>(_onDeleted);
  }

  final TripRecurrenceRepository _repository;
  final AnalyticsService? _analytics;

  /// Modèle de trajet récurrent créé, modifié ou supprimé : sans tracking, l'usage des
  /// récurrences ne se lisait qu'à travers `publish_draft_chosen`. Propriété
  /// `action` (`created`, `updated`, `deleted`).
  void _logSaved(String action) {
    final analytics = _analytics;
    if (analytics == null) return;
    unawaited(
      analytics.logEvent(
        AnalyticsEvents.tripRecurrenceSaved,
        properties: {'action': action},
      ),
    );
  }

  Future<void> _onLoaded(
    TripRecurrenceLoaded event,
    Emitter<TripRecurrenceState> emit,
  ) async {
    emit(state.copyWith(status: TripRecurrenceStatus.loading));
    try {
      final list = await _repository.getAll();
      emit(
        state.copyWith(status: TripRecurrenceStatus.success, recurrences: list),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TripRecurrenceStatus.error,
          error: unwrapDioError(e),
        ),
      );
    }
  }

  Future<void> _onCreated(
    TripRecurrenceCreated event,
    Emitter<TripRecurrenceState> emit,
  ) async {
    emit(state.copyWith(status: TripRecurrenceStatus.loading));
    try {
      final created = await _repository.create(event.data);
      emit(
        state.copyWith(
          status: TripRecurrenceStatus.success,
          recurrences: [created, ...state.recurrences],
        ),
      );
      _logSaved('created');
    } catch (e) {
      emit(
        state.copyWith(
          status: TripRecurrenceStatus.error,
          error: unwrapDioError(e),
        ),
      );
    }
  }

  Future<void> _onUpdated(
    TripRecurrenceUpdated event,
    Emitter<TripRecurrenceState> emit,
  ) async {
    emit(state.copyWith(status: TripRecurrenceStatus.loading));
    try {
      final updated = await _repository.update(event.id, event.data);
      final list = state.recurrences
          .map((r) => r.id == event.id ? updated : r)
          .toList();
      emit(
        state.copyWith(status: TripRecurrenceStatus.success, recurrences: list),
      );
      _logSaved('updated');
    } catch (e) {
      emit(
        state.copyWith(
          status: TripRecurrenceStatus.error,
          error: unwrapDioError(e),
        ),
      );
    }
  }

  Future<void> _onDeleted(
    TripRecurrenceDeleted event,
    Emitter<TripRecurrenceState> emit,
  ) async {
    try {
      await _repository.delete(event.id);
      final list = state.recurrences.where((r) => r.id != event.id).toList();
      emit(
        state.copyWith(status: TripRecurrenceStatus.success, recurrences: list),
      );
      _logSaved('deleted');
    } catch (e) {
      emit(
        state.copyWith(
          status: TripRecurrenceStatus.error,
          error: unwrapDioError(e),
        ),
      );
    }
  }
}
