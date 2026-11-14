import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/video_modal/bloc/video_modal_event.dart';
import 'package:dony/features/video_modal/bloc/video_modal_state.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/repositories/video_modal_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'video_modal_event.dart';
export 'video_modal_state.dart';

/// Modals vidéo de la session : campagnes éligibles, un seul modal par case
/// (type × où/moment) et par lancement, réponses envoyées au back ou gardées sur le téléphone.
///
/// Singleton (une session = un lancement de l'app) : le shell et les boutons
/// « Publier un trajet » / « Envoyer un colis » lisent le même état.
class VideoModalBloc extends Bloc<VideoModalEvent, VideoModalState> {
  VideoModalBloc(
    this._repository,
    this._analytics, {
    required bool Function() hasRealSession,
    DateTime Function()? clock,
  }) : _hasRealSession = hasRealSession,
       _clock = clock ?? DateTime.now,
       super(const VideoModalState()) {
    on<VideoModalLoadRequested>(_onLoad);
    on<VideoModalAppOpenConsumedRequested>(
      (_, emit) => emit(state.copyWith(appOpenConsumed: true)),
    );
    on<VideoModalAnswerRequested>(_onAnswer);
  }

  final VideoModalRepository _repository;
  final AnalyticsService _analytics;
  final bool Function() _hasRealSession;
  final DateTime Function() _clock;

  /// Clé du chargement en vol (`langue/compte`) : la même demande arrivée
  /// pendant le chargement est ignorée, une autre (connexion pendant le
  /// chargement visiteur) le remplace.
  String? _inFlight;

  Future<void> _onLoad(
    VideoModalLoadRequested event,
    Emitter<VideoModalState> emit,
  ) async {
    final key = '${event.lang}/${event.realSession}';
    if (_inFlight == key) return;
    if (!event.force &&
        _inFlight == null &&
        state.status == VideoModalStatus.ready &&
        state.loadedLang == event.lang &&
        state.loadedForRealSession == event.realSession) {
      return;
    }
    _inFlight = key;
    if (!event.force) emit(state.copyWith(status: VideoModalStatus.loading));
    if (event.realSession) {
      await _repository.syncGuestEvents();
    }
    final campaigns = await _repository.loadEligible(
      lang: event.lang,
      realSession: event.realSession,
    );
    if (_inFlight != key) return;
    _inFlight = null;
    emit(
      state.copyWith(
        status: VideoModalStatus.ready,
        campaigns: campaigns,
        loadedAt: _clock(),
        loadedLang: event.lang,
        loadedForRealSession: event.realSession,
      ),
    );
  }

  Future<void> _onAnswer(
    VideoModalAnswerRequested event,
    Emitter<VideoModalState> emit,
  ) async {
    if (event.event == VideoModalEventType.shown) {
      // « À chaque fois » : aucune case. Sinon la case (type de modal, nature
      // du déclencheur) : les autres cases restent libres.
      if (!event.campaign.isEveryTime) {
        emit(
          state.copyWith(
            usedSlots: {
              ...state.usedSlots,
              VideoModalSlot.of(event.campaign, moment: event.trigger.isMoment),
            },
          ),
        );
      }
    }
    final realSession = _hasRealSession();
    unawaited(
      _analytics.logEvent(
        switch (event.event) {
          VideoModalEventType.shown => AnalyticsEvents.videoModalShown,
          VideoModalEventType.opened => AnalyticsEvents.videoModalVideoOpened,
          VideoModalEventType.completed =>
            AnalyticsEvents.videoModalVideoCompleted,
          VideoModalEventType.dismissed => AnalyticsEvents.videoModalDismissed,
          VideoModalEventType.dontShowAgain =>
            AnalyticsEvents.videoModalDontShowAgain,
        },
        properties: {
          'campaign_id': event.campaign.id,
          'version': event.campaign.version,
          'trigger': event.trigger.wire,
          'guest': !realSession,
          'type': event.campaign.isInfo ? 'info' : 'video',
          if (event.actionKind != null)
            'action_kind': event.actionKind!.wire.toLowerCase(),
        },
      ),
    );
    await _repository.record(
      event.campaign,
      event.event,
      realSession: realSession,
    );
  }
}
