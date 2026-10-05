import 'dart:async';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:dony/features/messaging/presentation/chat_labels.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class _DeletedByOtherParty extends ChatEvent {
  const _DeletedByOtherParty();
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final FirestoreChatRepository _firestoreRepo;
  final ConversationRepository _conversationRepo;
  final AnalyticsService _analytics;
  StreamSubscription<dynamic>? _messageSub;
  StreamSubscription<bool>? _deletedSub;

  ChatBloc(this._firestoreRepo, this._conversationRepo, this._analytics)
    : super(const ChatInitial()) {
    on<ChatSubscribeRequested>(_onSubscribe);
    on<ChatTextSendRequested>(_onSendText);
    on<ChatImageSendRequested>(_onSendImage);
    on<ChatLocationSendRequested>(_onSendLocation);
    on<ChatConversationDeleteRequested>(_onDeleteConversation);
    on<_DeletedByOtherParty>(_onDeletedByOtherParty);
  }

  Future<void> _onSubscribe(
    ChatSubscribeRequested event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatLoading());
    await _messageSub?.cancel();
    await _deletedSub?.cancel();

    // Marquer lu aussi en read-only : sinon le compteur unread_* d'une
    // conversation dont l'interlocuteur a supprimé son compte ou sa copie
    // ne redescend jamais et le badge Messages reste bloqué.
    if (event.currentUserUid.isNotEmpty) {
      unawaited(
        _firestoreRepo.markConversationRead(
          event.firestoreConversationId,
          event.currentUserUid,
        ),
      );
      unawaited(
        _firestoreRepo.markMessagesRead(
          firestoreConversationId: event.firestoreConversationId,
          currentUserUid: event.currentUserUid,
        ),
      );
    }

    // Only watch deletion stream when NOT already in read-only
    // (if already read-only, the other party already deleted — stream would fire immediately)
    if (!event.isReadOnly) {
      _deletedSub = _firestoreRepo
          .conversationDeletedStream(event.firestoreConversationId)
          .listen(
            (deleted) {
              if (deleted && !isClosed) add(const _DeletedByOtherParty());
            },
            onError: (_) {
              // Session invalidée entre-temps (ex: signOut concurrent) — pas d'état d'erreur bloquant.
            },
          );
    }

    await emit.forEach<List<MessageModel>>(
      _firestoreRepo.messagesStream(event.firestoreConversationId),
      onData: (messages) =>
          event.isReadOnly ? ChatReadOnly(messages) : ChatLoaded(messages),
      onError: (e, st) => const ChatError(
        NetworkException(
          'Erreur de connexion à la messagerie', // i18n-ignore
          code: 'chat-stream-error',
        ),
      ),
    );
  }

  Future<void> _onSendText(
    ChatTextSendRequested event,
    Emitter<ChatState> emit,
  ) async {
    final sent = await _rejectable(
      emit,
      () => _firestoreRepo.sendTextMessage(
        firestoreConversationId: event.firestoreConversationId,
        senderFirebaseUid: event.senderFirebaseUid,
        body: event.body,
      ),
      text: event.body,
    );
    if (!sent) return;
    final preview = event.body.length > 80
        ? '${event.body.substring(0, 77)}...'
        : event.body;
    await _conversationRepo.updateLastMessage(event.conversationId, preview);
    unawaited(_analytics.logEvent(AnalyticsEvents.messageSent));
  }

  Future<void> _onSendImage(
    ChatImageSendRequested event,
    Emitter<ChatState> emit,
  ) async {
    final result = await _conversationRepo.uploadImage(
      event.conversationId,
      event.bytes,
      event.filename,
    );
    final sent = await _rejectable(
      emit,
      () => _firestoreRepo.sendImageMessage(
        firestoreConversationId: event.firestoreConversationId,
        senderFirebaseUid: event.senderFirebaseUid,
        imageUrl: result['presignedUrl']!,
      ),
    );
    if (!sent) return;
    await _conversationRepo.updateLastMessage(
      event.conversationId,
      kChatPreviewPhoto,
    );
  }

  Future<void> _onSendLocation(
    ChatLocationSendRequested event,
    Emitter<ChatState> emit,
  ) async {
    final sent = await _rejectable(
      emit,
      () => _firestoreRepo.sendLocationMessage(
        firestoreConversationId: event.firestoreConversationId,
        senderFirebaseUid: event.senderFirebaseUid,
        latitude: event.latitude,
        longitude: event.longitude,
      ),
    );
    if (!sent) return;
    await _conversationRepo.updateLastMessage(
      event.conversationId,
      kChatPreviewLocation,
    );
  }

  /// Écrit dans Firestore ; `false` si les règles refusent l'écriture
  /// (`permission-denied` : messagerie coupée par un administrateur ou
  /// conversation fermée). Le refus n'est plus une erreur non rattrapée
  /// (crash fatal Sentry FLUTTER-CV) : l'écran l'explique et rend le texte.
  /// Toute autre erreur remonte comme avant.
  Future<bool> _rejectable(
    Emitter<ChatState> emit,
    Future<void> Function() write, {
    String? text,
  }) async {
    try {
      await write();
      return true;
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      final previous = state;
      emit(ChatSendRejected(previous, text: text));
      emit(previous);
      return false;
    }
  }

  Future<void> _onDeleteConversation(
    ChatConversationDeleteRequested event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatDeletingConversation());
    // Cancel deletion stream BEFORE the API call so Firestore echo doesn't
    // trigger _DeletedByOtherParty after we already handle the deletion ourselves.
    await _deletedSub?.cancel();
    _deletedSub = null;

    // Reset the unread counter so the bottom-nav badge clears immediately.
    // Already a no-op when the user opened the chat (subscribe path does it),
    // but read-only chats never call markConversationRead, so do it here too.
    if (event.firestoreConversationId.isNotEmpty) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        if (uid.isNotEmpty) {
          await _firestoreRepo.markConversationRead(
            event.firestoreConversationId,
            uid,
          );
        }
      } catch (_) {
        // Non-fatal — proceed with the API deletion.
      }
    }

    try {
      await _conversationRepo.deleteConversation(event.conversationId);
      emit(const ChatConversationDeleted());
    } catch (e) {
      emit(ChatError(unwrapDioError(e)));
    }
  }

  void _onDeletedByOtherParty(
    _DeletedByOtherParty event,
    Emitter<ChatState> emit,
  ) {
    // The other party deleted — transition to read-only (keep showing messages)
    final current = state;
    final messages = current is ChatLoaded
        ? current.messages
        : <MessageModel>[];
    emit(ChatReadOnly(messages));
  }

  @override
  Future<void> close() async {
    await _messageSub?.cancel();
    await _deletedSub?.cancel();
    return super.close();
  }
}
