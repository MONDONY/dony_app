import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConversationOpenBloc
    extends Bloc<ConversationOpenEvent, ConversationOpenState> {
  final ConversationRepository _repository;
  final AnalyticsService _analytics;

  ConversationOpenBloc(this._repository, this._analytics)
    : super(const ConversationOpenInitial()) {
    on<ConversationOpenRequested>(
      (event, emit) => _open(emit, () => _repository.getByBidId(event.bidId)),
    );
    on<RecipientConversationOpenRequested>(_onRecipientOpen);
  }

  Future<void> _onRecipientOpen(
    RecipientConversationOpenRequested event,
    Emitter<ConversationOpenState> emit,
  ) async {
    // À l'appui, avant la réponse : le refus (403/404) est aussi une intention.
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.recipientMessageTapped,
        properties: {'role': event.role.name},
      ),
    );
    final opened = await _open(
      emit,
      () => _repository.getRecipientConversation(event.bidId),
    );
    if (opened) {
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.recipientConversationOpened,
          properties: {'role': event.role.name},
        ),
      );
    }
  }

  /// Récupère la conversation par [fetch], la restaure si l'utilisateur
  /// l'avait supprimée de son côté, et rend `true` quand elle est ouverte.
  Future<bool> _open(
    Emitter<ConversationOpenState> emit,
    Future<ConversationModel> Function() fetch,
  ) async {
    if (state is ConversationOpenLoading) return false;
    emit(const ConversationOpenLoading());
    try {
      var conversation = await fetch();
      if (conversation.deletedBySelf) {
        conversation = await _repository.restoreConversation(conversation.id);
      }
      emit(ConversationOpenSuccess(conversation));
      return true;
    } catch (e) {
      emit(ConversationOpenError(unwrapDioError(e)));
      return false;
    }
  }
}
