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
    emit(const ToolsCompletionState.loading());
    try {
      final model = await _repository.getToolsCompletion();
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.activitesHubToolsCompletionLoaded,
          properties: {'ready': model.ready, 'total': model.total},
        ),
      );
      emit(ToolsCompletionState.loaded(model));
    } catch (_) {
      emit(const ToolsCompletionState.hidden());
    }
  }
}
