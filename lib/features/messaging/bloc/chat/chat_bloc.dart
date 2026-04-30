import 'dart:async';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class _DeletedByOtherParty extends ChatEvent {
  const _DeletedByOtherParty();
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final FirestoreChatRepository _firestoreRepo;
  final ConversationRepository _conversationRepo;
  StreamSubscription<dynamic>? _messageSub;
  StreamSubscription<bool>? _deletedSub;

  ChatBloc(this._firestoreRepo, this._conversationRepo)
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

    // Watch for deletion by the other party
    _deletedSub = _firestoreRepo
        .conversationDeletedStream(event.firestoreConversationId)
        .listen((deleted) {
      if (deleted && !isClosed) {
        add(const _DeletedByOtherParty());
      }
    });

    await emit.forEach(
      _firestoreRepo.messagesStream(event.firestoreConversationId),
      onData: (messages) => ChatLoaded(messages),
      onError: (e, st) => const ChatError('Erreur de connexion au chat'),
    );
  }

  Future<void> _onSendText(
    ChatTextSendRequested event,
    Emitter<ChatState> emit,
  ) async {
    await _firestoreRepo.sendTextMessage(
      firestoreConversationId: event.firestoreConversationId,
      senderFirebaseUid: event.senderFirebaseUid,
      body: event.body,
    );
    final preview = event.body.length > 80
        ? '${event.body.substring(0, 77)}...'
        : event.body;
    await _conversationRepo.updateLastMessage(event.conversationId, preview);
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
    await _firestoreRepo.sendImageMessage(
      firestoreConversationId: event.firestoreConversationId,
      senderFirebaseUid: event.senderFirebaseUid,
      imageUrl: result['presignedUrl']!,
    );
    await _conversationRepo.updateLastMessage(event.conversationId, '📷 Photo');
  }

  Future<void> _onSendLocation(
    ChatLocationSendRequested event,
    Emitter<ChatState> emit,
  ) async {
    await _firestoreRepo.sendLocationMessage(
      firestoreConversationId: event.firestoreConversationId,
      senderFirebaseUid: event.senderFirebaseUid,
      latitude: event.latitude,
      longitude: event.longitude,
    );
    await _conversationRepo.updateLastMessage(
      event.conversationId,
      '📍 Localisation partagée',
    );
  }

  Future<void> _onDeleteConversation(
    ChatConversationDeleteRequested event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatDeletingConversation());
    // Cancel the deletion stream first to avoid a double-emit when Firestore
    // echoes back the deletedAt field we're about to set via the API.
    await _deletedSub?.cancel();
    _deletedSub = null;
    try {
      await _conversationRepo.deleteConversation(event.conversationId);
      emit(const ChatConversationDeleted());
    } catch (_) {
      emit(const ChatError('Impossible de supprimer la conversation'));
    }
  }

  void _onDeletedByOtherParty(
    _DeletedByOtherParty event,
    Emitter<ChatState> emit,
  ) {
    emit(const ChatConversationDeleted());
  }

  @override
  Future<void> close() async {
    await _messageSub?.cancel();
    await _deletedSub?.cancel();
    return super.close();
  }
}
