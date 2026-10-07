import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Issue ponctuelle d'une bascule, lue par l'écran pour sa snackbar.
enum ConversationNotificationsOutcome { muted, unmuted, failed }

/// Sourdine de la conversation affichée dans l'écran de chat (FLUTTER-CM).
///
/// [muted] est mis à jour avant la réponse du serveur, puis remis en place si
/// l'appel échoue (403, réseau, ou 404/405 d'un back sans la route).
/// [outcome] et [error] ne valent que pour l'émission qui les porte : la
/// suivante les remet à `null`.
class ConversationNotificationsState {
  final bool muted;
  final bool inFlight;
  final ConversationNotificationsOutcome? outcome;
  final AppException? error;

  const ConversationNotificationsState({
    required this.muted,
    this.inFlight = false,
    this.outcome,
    this.error,
  });
}

class ConversationNotificationsCubit
    extends Cubit<ConversationNotificationsState> {
  ConversationNotificationsCubit(
    this._repository,
    this._analytics, {
    required ConversationModel conversation,
  }) : _conversationId = conversation.id,
       super(
         ConversationNotificationsState(muted: conversation.notificationsMuted),
       );

  final ConversationRepository _repository;
  final AnalyticsService _analytics;
  final String _conversationId;

  /// Bascule sourdine ↔ notifications. Ignoré pendant un appel en cours : un
  /// double tap n'envoie pas deux requêtes contradictoires.
  Future<void> toggle() async {
    if (state.inFlight) return;
    final target = !state.muted;
    emit(ConversationNotificationsState(muted: target, inFlight: true));
    try {
      if (target) {
        await _repository.muteConversationNotifications(_conversationId);
      } else {
        await _repository.unmuteConversationNotifications(_conversationId);
      }
    } catch (e) {
      if (isClosed) return;
      emit(
        ConversationNotificationsState(
          muted: !target,
          outcome: ConversationNotificationsOutcome.failed,
          error: unwrapDioError(e),
        ),
      );
      return;
    }
    unawaited(
      _analytics.logEvent(
        target
            ? AnalyticsEvents.conversationNotificationsMuted
            : AnalyticsEvents.conversationNotificationsUnmuted,
        properties: const {'source': 'chat'},
      ),
    );
    if (isClosed) return;
    emit(
      ConversationNotificationsState(
        muted: target,
        outcome: target
            ? ConversationNotificationsOutcome.muted
            : ConversationNotificationsOutcome.unmuted,
      ),
    );
  }
}
