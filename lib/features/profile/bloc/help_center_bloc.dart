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
    on<HelpCenterLoadRequested>(
      _onLoadRequested,
      transformer: _sequential(),
    );
    on<HelpCenterOpenRequested>(_onOpenRequested);
    on<HelpTutorialOpenRequested>(_onTutorialOpenRequested);
    on<HelpTutorialPlaybackRequested>(_onPlaybackRequested);
    on<HelpExternalOpenRequested>(_onExternalOpenRequested);
  }

  final HelpCenterRepository _repository;
  final AnalyticsService _analytics;
  HelpCenterConfig _stableConfig = HelpCenterConfig.empty;

  Future<void> _onLoadRequested(
    HelpCenterLoadRequested event,
    Emitter<HelpCenterState> emit,
  ) async {
    final previousConfig = _stableConfig;
    emit(const HelpCenterLoading());

    HelpCenterRepositoryResult loadResult;
    try {
      loadResult = await _repository.load();
    } on FormatException {
      _emitFailure('parse', previousConfig, emit);
      return;
    } catch (_) {
      _emitFailure('fetch', previousConfig, emit);
      return;
    }

    final cachedConfig = loadResult.config;
    _stableConfig = cachedConfig;
    emit(HelpCenterSuccess(cachedConfig, isRefreshing: true));

    HelpCenterRepositoryResult refreshResult;
    try {
      refreshResult = await _repository.refresh();
    } on FormatException {
      _emitFailure('parse', cachedConfig, emit);
      return;
    } catch (_) {
      _emitFailure('fetch', cachedConfig, emit);
      return;
    }

    final failure = refreshResult.failure;
    if (failure != null) {
      _emitFailure(failure.name, cachedConfig, emit);
      return;
    }
    final refreshedConfig = refreshResult.config;
    _stableConfig = refreshedConfig;
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
    // Chaque intention explicite est tracée. Le lecteur de la Task 5
    // déduplique ses callbacks par cycle de vie avant de les envoyer au BLoC.
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
    final stableConfig = _stableConfig;
    final opened = await _repository.openExternal(event.uri);
    if (!opened) {
      _emitFailure('launch', stableConfig, emit);
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

EventTransformer<Event> _sequential<Event>() {
  return (events, mapper) => events.asyncExpand(mapper);
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
  TutorialContext.corridorAlerts => 'corridor_alerts',
  TutorialContext.tripTemplates => 'trip_templates',
  TutorialContext.recipients => 'recipients',
  TutorialContext.receivedRequests => 'received_requests',
};
