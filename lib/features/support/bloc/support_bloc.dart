import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'support_event.dart';
part 'support_state.dart';

/// Workflow support côté utilisateur : assistant (réponses prédéfinies),
/// création de ticket, fil de messages. Un ticket RESOLVED n'accepte plus
/// d'écriture — la règle est appliquée ici avant tout appel réseau, le
/// backend la fait respecter de toute façon (422).
class SupportBloc extends Bloc<SupportEvent, SupportState> {
  SupportBloc(this._repository, this._analytics) : super(const SupportState()) {
    on<SupportHomeRequested>(_onHomeRequested);
    on<SupportTicketCreateRequested>(_onCreateRequested);
    on<SupportTicketDetailRequested>(_onDetailRequested);
    on<SupportMessageSendRequested>(_onMessageSendRequested);
  }

  final SupportRepository _repository;
  final AnalyticsService _analytics;

  Future<void> _onHomeRequested(
    SupportHomeRequested event,
    Emitter<SupportState> emit,
  ) async {
    emit(state.copyWith(homeStatus: SupportViewStatus.loading));
    try {
      final results = await Future.wait([
        _repository.loadReplies(),
        _repository.loadTickets(),
      ]);
      emit(state.copyWith(
        homeStatus: SupportViewStatus.ready,
        replies: results[0] as List<SupportPredefinedReply>,
        tickets: results[1] as List<SupportTicket>,
      ));
    } catch (e) {
      emit(state.copyWith(
        homeStatus: SupportViewStatus.failure,
        errorMessage: _message(e),
      ));
    }
  }

  Future<void> _onCreateRequested(
    SupportTicketCreateRequested event,
    Emitter<SupportState> emit,
  ) async {
    emit(state.copyWith(createStatus: SupportActionStatus.submitting));
    try {
      final ticket = await _repository.createTicket(
        category: event.category,
        subject: event.subject,
        message: event.message,
      );
      unawaited(_analytics.logEvent(
        AnalyticsEvents.supportTicketCreated,
        properties: {'category': event.category},
      ));
      emit(state.copyWith(
        createStatus: SupportActionStatus.success,
        createdTicketId: ticket.id,
        tickets: [ticket, ...state.tickets],
      ));
    } catch (e) {
      emit(state.copyWith(
        createStatus: SupportActionStatus.failure,
        errorMessage: _message(e),
      ));
    }
  }

  Future<void> _onDetailRequested(
    SupportTicketDetailRequested event,
    Emitter<SupportState> emit,
  ) async {
    emit(state.copyWith(detailStatus: SupportViewStatus.loading));
    try {
      final ticket = await _repository.loadTicket(event.ticketId);
      emit(state.copyWith(
        detailStatus: SupportViewStatus.ready,
        ticket: ticket,
      ));
    } catch (e) {
      emit(state.copyWith(
        detailStatus: SupportViewStatus.failure,
        errorMessage: _message(e),
      ));
    }
  }

  Future<void> _onMessageSendRequested(
    SupportMessageSendRequested event,
    Emitter<SupportState> emit,
  ) async {
    final current = state.ticket;
    if (current != null && current.isResolved) {
      emit(state.copyWith(
        sendStatus: SupportActionStatus.failure,
        errorMessage:
            'Ce ticket est résolu. Ouvrez-en un nouveau pour un autre problème.',
      ));
      return;
    }
    emit(state.copyWith(sendStatus: SupportActionStatus.submitting));
    try {
      await _repository.sendMessage(event.ticketId, event.content);
      unawaited(
        _analytics.logEvent(AnalyticsEvents.supportTicketMessageSent),
      );
      // Le fil rechargé fait foi : statut mis à jour (WAITING_SUPPORT) et
      // message horodaté par le serveur.
      final ticket = await _repository.loadTicket(event.ticketId);
      emit(state.copyWith(
        sendStatus: SupportActionStatus.success,
        detailStatus: SupportViewStatus.ready,
        ticket: ticket,
      ));
    } catch (e) {
      emit(state.copyWith(
        sendStatus: SupportActionStatus.failure,
        errorMessage: _message(e),
      ));
    }
  }

  /// Extrait le `detail` RFC 7807 renvoyé par le backend, sinon un message
  /// générique. Jamais de stack trace ni de message technique à l'écran.
  static String _message(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
      }
    }
    return 'Une erreur est survenue. Réessayez.';
  }
}
