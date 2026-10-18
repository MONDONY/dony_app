import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_template_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TripTemplateBloc extends Bloc<TripTemplateEvent, TripTemplateState> {
  TripTemplateBloc(this._repository, {AnalyticsService? analytics})
    : _analytics = analytics,
      super(const TripTemplateState()) {
    on<TripTemplateLoaded>(_onLoaded);
    on<TripTemplateCreated>(_onCreated);
    on<TripTemplateUpdated>(_onUpdated);
    on<TripTemplateDeleted>(_onDeleted);
  }

  final TripTemplateRepository _repository;
  final AnalyticsService? _analytics;

  /// Modèle de trajet créé, modifié ou supprimé : sans tracking, l'usage des
  /// modèles ne se lisait qu'à travers `publish_draft_chosen`. Propriété
  /// `action` (`created`, `updated`, `deleted`).
  void _logSaved(String action) {
    final analytics = _analytics;
    if (analytics == null) return;
    unawaited(
      analytics.logEvent(
        AnalyticsEvents.tripTemplateSaved,
        properties: {'action': action},
      ),
    );
  }

  Future<void> _onLoaded(
    TripTemplateLoaded event,
    Emitter<TripTemplateState> emit,
  ) async {
    emit(state.copyWith(status: TripTemplateStatus.loading));
    try {
      final templates = await _repository.getAll();
      emit(
        state.copyWith(
          status: TripTemplateStatus.success,
          templates: templates,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TripTemplateStatus.error,
          error: unwrapDioError(e),
        ),
      );
    }
  }

  Future<void> _onCreated(
    TripTemplateCreated event,
    Emitter<TripTemplateState> emit,
  ) async {
    emit(state.copyWith(status: TripTemplateStatus.loading));
    try {
      final created = await _repository.create(event.data);
      emit(
        state.copyWith(
          status: TripTemplateStatus.success,
          templates: [created, ...state.templates],
        ),
      );
      _logSaved('created');
    } catch (e) {
      emit(
        state.copyWith(
          status: TripTemplateStatus.error,
          error: unwrapDioError(e),
        ),
      );
    }
  }

  Future<void> _onUpdated(
    TripTemplateUpdated event,
    Emitter<TripTemplateState> emit,
  ) async {
    emit(state.copyWith(status: TripTemplateStatus.loading));
    try {
      final updated = await _repository.update(event.id, event.data);
      final templates = state.templates
          .map((t) => t.id == event.id ? updated : t)
          .toList();
      emit(
        state.copyWith(
          status: TripTemplateStatus.success,
          templates: templates,
        ),
      );
      _logSaved('updated');
    } catch (e) {
      emit(
        state.copyWith(
          status: TripTemplateStatus.error,
          error: unwrapDioError(e),
        ),
      );
    }
  }

  Future<void> _onDeleted(
    TripTemplateDeleted event,
    Emitter<TripTemplateState> emit,
  ) async {
    try {
      await _repository.delete(event.id);
      final templates = state.templates.where((t) => t.id != event.id).toList();
      emit(
        state.copyWith(
          status: TripTemplateStatus.success,
          templates: templates,
        ),
      );
      _logSaved('deleted');
    } catch (e) {
      emit(
        state.copyWith(
          status: TripTemplateStatus.error,
          error: unwrapDioError(e),
        ),
      );
    }
  }
}
