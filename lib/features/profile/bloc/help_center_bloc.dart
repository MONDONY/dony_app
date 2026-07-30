import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'help_center_event.dart';
part 'help_center_state.dart';

final class HelpCenterBloc extends Bloc<HelpCenterEvent, HelpCenterState> {
  HelpCenterBloc(this._repository, this._analytics)
    : super(const HelpCenterInitial()) {
    on<HelpCenterLoadRequested>(_onLoadRequested);
    on<HelpCenterOpenRequested>(_onOpenRequested);
    on<HelpTutorialOpenRequested>(_onTutorialOpenRequested);
    on<HelpTutorialPlaybackRequested>(_onPlaybackRequested);
    on<HelpExternalOpenRequested>(_onExternalOpenRequested);
  }

  final HelpCenterRepository _repository;
  final AnalyticsService _analytics;

  Future<void> _onLoadRequested(
    HelpCenterLoadRequested event,
    Emitter<HelpCenterState> emit,
  ) async {
    final previousConfig = _currentConfig;
    emit(const HelpCenterLoading());

    HelpCenterConfig cachedConfig;
    try {
      cachedConfig = await _repository.load();
    } on FormatException {
      _emitFailure('parse', previousConfig, emit);
      return;
    } catch (_) {
      _emitFailure('fetch', previousConfig, emit);
      return;
    }

    emit(HelpCenterSuccess(cachedConfig, isRefreshing: true));

    HelpCenterConfig refreshedConfig;
    try {
      refreshedConfig = await _repository.refresh();
    } on FormatException {
      _emitFailure('parse', cachedConfig, emit);
      return;
    } catch (_) {
      _emitFailure('fetch', cachedConfig, emit);
      return;
    }

    final failure = _repository.lastFailure;
    if (failure != null) {
      _emitFailure(failure.name, cachedConfig, emit);
      return;
    }
    emit(HelpCenterSuccess(refreshedConfig));
  }

  void _onOpenRequested(
    HelpCenterOpenRequested event,
    Emitter<HelpCenterState> emit,
  ) {
    unawaited(_analytics.logEvent(AnalyticsEvents.helpCenterOpened));
  }

  void _onTutorialOpenRequested(
    HelpTutorialOpenRequested event,
    Emitter<HelpCenterState> emit,
  ) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.helpTutorialOpened,
        properties: {
          'tutorial_id': event.tutorialId,
          'source': _sourceName(event.source),
        },
      ),
    );
  }

  void _onPlaybackRequested(
    HelpTutorialPlaybackRequested event,
    Emitter<HelpCenterState> emit,
  ) {
    final analyticsEvent = switch (event.action) {
      HelpPlaybackAction.started => AnalyticsEvents.helpTutorialPlayStarted,
      HelpPlaybackAction.completed => AnalyticsEvents.helpTutorialCompleted,
    };
    unawaited(
      _analytics.logEvent(
        analyticsEvent,
        properties: {'tutorial_id': event.tutorialId},
      ),
    );
  }

  Future<void> _onExternalOpenRequested(
    HelpExternalOpenRequested event,
    Emitter<HelpCenterState> emit,
  ) async {
    final opened = await _repository.openExternal(event.uri);
    if (!opened) {
      _emitFailure('launch', _currentConfig, emit);
      return;
    }

    final (analyticsEvent, properties) = switch (event.target) {
      HelpExternalTarget.tutorial => (
        AnalyticsEvents.helpTutorialExternalOpened,
        <String, Object>{'tutorial_id': event.tutorialId!},
      ),
      HelpExternalTarget.social => (
        AnalyticsEvents.helpSocialLinkOpened,
        <String, Object>{'network': event.network!.name},
      ),
      HelpExternalTarget.youtubeSubscription => (
        AnalyticsEvents.helpYoutubeSubscribeTapped,
        <String, Object>{'source': _sourceName(event.source)},
      ),
    };
    unawaited(_analytics.logEvent(analyticsEvent, properties: properties));
  }

  HelpCenterConfig get _currentConfig => switch (state) {
    HelpCenterSuccess(:final config) ||
    HelpCenterError(:final config) => config,
    _ => HelpCenterConfig.empty,
  };

  void _emitFailure(
    String reason,
    HelpCenterConfig config,
    Emitter<HelpCenterState> emit,
  ) {
    emit(HelpCenterError(reason, config: config));
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.helpConfigLoadFailed,
        properties: {'reason': reason},
      ),
    );
  }
}

String _sourceName(TutorialContext? source) => switch (source) {
  null => 'help_center',
  TutorialContext.search => 'search',
  TutorialContext.activities => 'activities',
  TutorialContext.tripPublish => 'trip_publish',
  TutorialContext.requestPublish => 'request_publish',
  TutorialContext.negotiation => 'negotiation',
  TutorialContext.payment => 'payment',
  TutorialContext.qrHandover => 'qr_handover',
  TutorialContext.tracking => 'tracking',
  TutorialContext.dispute => 'dispute',
};
