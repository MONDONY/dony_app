import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/tools_completion_model.dart';
import 'package:dony/features/matching/data/repositories/tools_completion_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ToolsCompletionStatus { initial, loading, loaded, hidden }

class ToolsCompletionState extends Equatable {
  const ToolsCompletionState._(this.status, [this.model]);

  const ToolsCompletionState.initial() : this._(ToolsCompletionStatus.initial);
  const ToolsCompletionState.loading() : this._(ToolsCompletionStatus.loading);
  const ToolsCompletionState.loaded(ToolsCompletionModel model)
    : this._(ToolsCompletionStatus.loaded, model);

  /// Échec réseau : carte masquée, tuiles sans badge. Jamais un faux « 0 / 5 ».
  const ToolsCompletionState.hidden() : this._(ToolsCompletionStatus.hidden);

  final ToolsCompletionStatus status;
  final ToolsCompletionModel? model;

  @override
  List<Object?> get props => [status, ...?model?.tools.map((t) => t.count)];
}

class ToolsCompletionCubit extends Cubit<ToolsCompletionState> {
  ToolsCompletionCubit(this._repository, this._analytics)
    : super(const ToolsCompletionState.initial());

  final ToolsCompletionRepository _repository;
  final AnalyticsService _analytics;

  Future<void> load() async {
    // Rechargement avec un modèle déjà connu : on le garde à l'écran, sinon la
    // carte et les badges clignotent à chaque retour d'un outil.
    if (state.model == null) {
      emit(const ToolsCompletionState.loading());
    }
    try {
      final previous = state.model;
      final model = await _repository.getToolsCompletion();
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.activitesHubToolsCompletionLoaded,
          properties: {'ready': model.ready, 'total': model.total},
        ),
      );
      if (previous != null) _trackProgress(previous, model);
      emit(ToolsCompletionState.loaded(model));
    } catch (_) {
      emit(const ToolsCompletionState.hidden());
    }
  }

  /// Compare deux chargements successifs : un outil qui passe de 0 à au moins
  /// un élément est « configuré », et le dernier outil rempli ferme la
  /// configuration (`ready == total`). Sans modèle précédent il n'y a rien à
  /// comparer : un compte déjà complet à l'ouverture n'émet rien.
  void _trackProgress(
    ToolsCompletionModel previous,
    ToolsCompletionModel model,
  ) {
    final before = {for (final t in previous.tools) t.key: t.ready};
    for (final tool in model.tools) {
      if (tool.ready && before[tool.key] == false) {
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.toolConfigured,
            properties: {
              'tool': tool.key.apiKey,
              'ready': model.ready,
              'total': model.total,
            },
          ),
        );
      }
    }
    if (model.ready == model.total && previous.ready < previous.total) {
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.toolsSetupCompleted,
          properties: {'total': model.total},
        ),
      );
    }
  }
}
