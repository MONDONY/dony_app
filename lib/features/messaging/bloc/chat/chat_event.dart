import 'dart:typed_data';

import 'package:dony/features/messaging/data/models/message_model.dart';

abstract class ChatEvent {
  const ChatEvent();
}

class ChatSubscribeRequested extends ChatEvent {
  final String firestoreConversationId;
  final String currentUserUid;
  final bool isReadOnly;
  const ChatSubscribeRequested(
    this.firestoreConversationId, {
    this.currentUserUid = '',
    this.isReadOnly = false,
  });
}

class ChatTextSendRequested extends ChatEvent {
  final String firestoreConversationId;
  final String conversationId;
  final String senderFirebaseUid;
  final String body;

  /// Message cité (FLUTTER-86), `null` hors réponse.
  final String? replyToId;
  const ChatTextSendRequested({
    required this.firestoreConversationId,
    required this.conversationId,
    required this.senderFirebaseUid,
    required this.body,
    this.replyToId,
  });
}

class ChatImageSendRequested extends ChatEvent {
  final String conversationId;
  final String firestoreConversationId;
  final String senderFirebaseUid;
  final Uint8List bytes;
  final String filename;
  final String? replyToId;
  const ChatImageSendRequested({
    required this.conversationId,
    required this.firestoreConversationId,
    required this.senderFirebaseUid,
    required this.bytes,
    required this.filename,
    this.replyToId,
  });
}

class ChatLocationSendRequested extends ChatEvent {
  final String firestoreConversationId;
  final String conversationId;
  final String senderFirebaseUid;
  final double latitude;
  final double longitude;
  final String? replyToId;
  const ChatLocationSendRequested({
    required this.firestoreConversationId,
    required this.conversationId,
    required this.senderFirebaseUid,
    required this.latitude,
    required this.longitude,
    this.replyToId,
  });
}

class ChatConversationDeleteRequested extends ChatEvent {
  final String conversationId;
  final String firestoreConversationId;
  const ChatConversationDeleteRequested({
    required this.conversationId,
    required this.firestoreConversationId,
  });
}

/// Appui long « Répondre » ou balayage d'une bulle : [message] devient la
/// citation du prochain envoi (FLUTTER-86).
class ChatReplyStarted extends ChatEvent {
  final MessageModel message;
  const ChatReplyStarted(this.message);
}

/// ✕ de la barre « Réponse à … » : le prochain envoi n'est plus une réponse.
class ChatReplyCancelled extends ChatEvent {
  const ChatReplyCancelled();
}
