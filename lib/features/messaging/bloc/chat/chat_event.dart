import 'dart:typed_data';

import 'package:dony/features/messaging/data/models/message_model.dart';

abstract class ChatEvent {
  const ChatEvent();
}

class ChatSubscribeRequested extends ChatEvent {
  final String firestoreConversationId;
  final String currentUserUid;
  final bool isReadOnly;

  /// Id API de la conversation (`conversations.id`), nécessaire à l'envoi
  /// d'une photo et à la relecture de la conversation après un refus.
  final String conversationId;

  /// Photos permises à l'ouverture (`ConversationModel.mediaAllowed`).
  final bool mediaAllowed;
  const ChatSubscribeRequested(
    this.firestoreConversationId, {
    this.currentUserUid = '',
    this.isReadOnly = false,
    this.conversationId = '',
    this.mediaAllowed = false,
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

/// Envoi d'une photo validée dans l'aperçu (FLUTTER-B4) : le back la stocke
/// et écrit lui-même le message dans Firestore. Une bulle locale « Envoi… »
/// s'affiche jusqu'à l'arrivée du vrai message.
class ChatImageSendRequested extends ChatEvent {
  final String conversationId;
  final Uint8List bytes;
  final String? replyToId;
  const ChatImageSendRequested({
    required this.conversationId,
    required this.bytes,
    this.replyToId,
  });
}

/// « Réessayer » sur une bulle photo non envoyée.
class ChatImageRetryRequested extends ChatEvent {
  final String localId;
  const ChatImageRetryRequested(this.localId);
}

/// « Supprimer » sur une bulle photo non envoyée : elle disparaît du fil.
class ChatImageDiscardRequested extends ChatEvent {
  final String localId;
  const ChatImageDiscardRequested(this.localId);
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
