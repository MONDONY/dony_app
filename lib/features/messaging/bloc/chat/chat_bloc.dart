import 'dart:async';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final FirestoreChatRepository _firestoreRepo;
  final ConversationRepository _conversationRepo;
  StreamSubscription<dynamic>? _sub;

  ChatBloc(this._firestoreRepo, this._conversationRepo)
      : super(const ChatInitial()) {
    on<ChatSubscribeRequested>(_onSubscribe);
    on<ChatTextSendRequested>(_onSendText);
    on<ChatImageSendRequested>(_onSendImage);
  }

  Future<void> _onSubscribe(
    ChatSubscribeRequested event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatLoading());
    await _sub?.cancel();

    // Reset unread count for this conversation when the user opens it
    if (event.currentUserUid.isNotEmpty) {
      unawaited(
        _firestoreRepo.markConversationRead(
          event.firestoreConversationId,
          event.currentUserUid,
        ),
      );
    }

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
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
