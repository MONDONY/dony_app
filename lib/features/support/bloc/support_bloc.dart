import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/support/data/support_attachment.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

part 'support_event.dart';
part 'support_state.dart';

/// Workflow support côté utilisateur : assistant (réponses prédéfinies),
/// création de ticket, fil de messages. Un ticket RESOLVED n'accepte plus
/// d'écriture — la règle est appliquée ici avant tout appel réseau, le
/// backend la fait respecter de toute façon (422).
///
/// [incomingMessages] diffuse l'identifiant du ticket de chaque message
/// support reçu au premier plan (`SupportLiveEvents`) : si c'est le fil
/// affiché, il est rechargé en place.
class SupportBloc extends Bloc<SupportEvent, SupportState> {
  SupportBloc(
    this._repository,
    this._analytics, {
    Stream<String>? incomingMessages,
  }) : super(const SupportState()) {
    on<SupportHomeRequested>(_onHomeRequested);
    on<SupportTicketCreateRequested>(_onCreateRequested);
    on<SupportTicketDetailRequested>(_onDetailRequested);
    on<SupportMessageSendRequested>(_onMessageSendRequested);
    on<SupportAttachmentPickRequested>(_onAttachmentPickRequested);
    on<SupportAttachmentRemoved>(_onAttachmentRemoved);
    on<SupportTicketLiveRefreshRequested>(_onLiveRefreshRequested);
    on<SupportTicketHideRequested>(_onHideRequested);
    _incomingSub = incomingMessages?.listen((ticketId) {
      final ticket = state.ticket;
      if (ticket != null &&
          ticket.id == ticketId &&
          state.detailStatus == SupportViewStatus.ready) {
        add(SupportTicketLiveRefreshRequested(ticketId));
      }
    });
  }

  final SupportRepository _repository;
  final AnalyticsService _analytics;
  StreamSubscription<String>? _incomingSub;

  @override
  Future<void> close() async {
    await _incomingSub?.cancel();
    return super.close();
  }

  static const _uuid = Uuid();

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
      emit(
        state.copyWith(
          homeStatus: SupportViewStatus.ready,
          replies: results[0] as List<SupportPredefinedReply>,
          tickets: results[1] as List<SupportTicket>,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          homeStatus: SupportViewStatus.failure,
          failure: SupportFailure.generic,
          serverDetail: _serverDetail(e),
        ),
      );
    }
  }

  /// Retire aussitôt le ticket de la liste, puis le confirme au back ; en
  /// cas d'échec, la liste revient telle qu'elle était (FLUTTER-9W).
  Future<void> _onHideRequested(
    SupportTicketHideRequested event,
    Emitter<SupportState> emit,
  ) async {
    final before = state.tickets;
    final ticket = before.where((t) => t.id == event.ticketId).firstOrNull;
    // Règle appliquée avant tout appel : seul un ticket résolu se retire.
    if (ticket == null || !ticket.isResolved) return;
    emit(
      state.copyWith(
        tickets: before.where((t) => t.id != event.ticketId).toList(),
      ),
    );
    try {
      await _repository.hideTicket(event.ticketId);
      unawaited(_analytics.logEvent(AnalyticsEvents.supportTicketHidden));
    } catch (e) {
      emit(
        state.copyWith(
          tickets: before,
          hideStatus: SupportActionStatus.failure,
          failure: SupportFailure.hideFailed,
          serverDetail: _serverDetail(e),
        ),
      );
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
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.supportTicketCreated,
          properties: {'category': event.category},
        ),
      );
      emit(
        state.copyWith(
          createStatus: SupportActionStatus.success,
          createdTicketId: ticket.id,
          tickets: [ticket, ...state.tickets],
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          createStatus: SupportActionStatus.failure,
          failure: SupportFailure.generic,
          serverDetail: _serverDetail(e),
        ),
      );
    }
  }

  Future<void> _onDetailRequested(
    SupportTicketDetailRequested event,
    Emitter<SupportState> emit,
  ) async {
    emit(state.copyWith(detailStatus: SupportViewStatus.loading));
    // Charger le fil en PREMIER : le backend recalcule unreadCount à la volée
    // depuis user_last_read_at. Si on marquait lu avant de charger, la réponse
    // porterait toujours unreadCount = 0 et la pastille ne s'éteindrait jamais.
    try {
      final ticket = await _repository.loadTicket(event.ticketId);
      // Marquer comme lu APRÈS le chargement. Un échec du marquage ne doit
      // jamais empêcher l'utilisateur de lire son fil.
      try {
        await _repository.markRead(event.ticketId);
      } catch (_) {
        // silence intentionnel
      }
      emit(
        state.copyWith(detailStatus: SupportViewStatus.ready, ticket: ticket),
      );
    } catch (e) {
      emit(
        state.copyWith(
          detailStatus: SupportViewStatus.failure,
          failure: SupportFailure.generic,
          serverDetail: _serverDetail(e),
        ),
      );
    }
  }

  Future<void> _onLiveRefreshRequested(
    SupportTicketLiveRefreshRequested event,
    Emitter<SupportState> emit,
  ) async {
    try {
      final ticket = await _repository.loadTicket(event.ticketId);
      try {
        await _repository.markRead(event.ticketId);
      } catch (_) {
        // silence intentionnel : le fil reste lisible
      }
      emit(
        state.copyWith(
          detailStatus: SupportViewStatus.ready,
          ticket: ticket,
          liveRefreshCount: state.liveRefreshCount + 1,
        ),
      );
    } catch (_) {
      // silence intentionnel : le fil déjà affiché reste à l'écran
    }
  }

  Future<void> _onMessageSendRequested(
    SupportMessageSendRequested event,
    Emitter<SupportState> emit,
  ) async {
    final current = state.ticket;
    if (current != null && current.isResolved) {
      emit(
        state.copyWith(
          sendStatus: SupportActionStatus.failure,
          failure: SupportFailure.ticketResolved,
        ),
      );
      return;
    }
    // Ne transmettre que les clés des images prêtes ; les images en échec
    // sont silencieusement ignorées (l'utilisateur les voit en rouge).
    final readyKeys = state.pendingAttachments
        .where((a) => a.status == SupportUploadStatus.ready)
        .map((a) => a.remoteKey!)
        .toList();
    emit(state.copyWith(sendStatus: SupportActionStatus.submitting));
    try {
      await _repository.sendMessage(event.ticketId, event.content, readyKeys);
      unawaited(_analytics.logEvent(AnalyticsEvents.supportTicketMessageSent));
      // Le fil rechargé fait foi : statut mis à jour (WAITING_SUPPORT) et
      // message horodaté par le serveur.
      final ticket = await _repository.loadTicket(event.ticketId);
      emit(
        state.copyWith(
          sendStatus: SupportActionStatus.success,
          detailStatus: SupportViewStatus.ready,
          ticket: ticket,
          pendingAttachments: const [],
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          sendStatus: SupportActionStatus.failure,
          failure: SupportFailure.generic,
          serverDetail: _serverDetail(e),
        ),
      );
    }
  }

  Future<void> _onAttachmentPickRequested(
    SupportAttachmentPickRequested event,
    Emitter<SupportState> emit,
  ) async {
    final localId = _uuid.v4();
    final uploading = SupportAttachmentUpload(
      localId: localId,
      localPath: event.localPath,
      status: SupportUploadStatus.uploading,
    );
    emit(
      state.copyWith(
        pendingAttachments: [...state.pendingAttachments, uploading],
      ),
    );
    try {
      final remoteKey = await _repository.uploadAttachment(event.localPath);
      unawaited(_analytics.logEvent(AnalyticsEvents.supportAttachmentAdded));
      final updated = state.pendingAttachments
          .map(
            (a) => a.localId == localId
                ? a.copyWith(
                    status: SupportUploadStatus.ready,
                    remoteKey: remoteKey,
                  )
                : a,
          )
          .toList();
      emit(state.copyWith(pendingAttachments: updated));
    } catch (_) {
      final updated = state.pendingAttachments
          .map(
            (a) => a.localId == localId
                ? a.copyWith(status: SupportUploadStatus.failed)
                : a,
          )
          .toList();
      emit(state.copyWith(pendingAttachments: updated));
    }
  }

  void _onAttachmentRemoved(
    SupportAttachmentRemoved event,
    Emitter<SupportState> emit,
  ) {
    emit(
      state.copyWith(
        pendingAttachments: state.pendingAttachments
            .where((a) => a.localId != event.localId)
            .toList(),
      ),
    );
  }

  /// Extrait le `detail` RFC 7807 renvoyé par le backend, `null` sinon : dans
  /// ce cas la présentation retombe sur un message générique localisé
  /// (`supportErrorMessage`). Jamais de stack trace ni de message technique
  /// à l'écran.
  static String? _serverDetail(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
      }
    }
    return null;
  }
}
