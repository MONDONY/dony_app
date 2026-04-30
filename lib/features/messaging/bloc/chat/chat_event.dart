import 'dart:typed_data';

abstract class ChatEvent {
  const ChatEvent();
}

class ChatSubscribeRequested extends ChatEvent {
  final String firestoreConversationId;
  final String currentUserUid;
  const ChatSubscribeRequested(
    this.firestoreConversationId, {
    this.currentUserUid = '',
  });
}

class ChatTextSendRequested extends ChatEvent {
  final String firestoreConversationId;
  final String conversationId;
  final String senderFirebaseUid;
  final String body;
  const ChatTextSendRequested({
    required this.firestoreConversationId,
    required this.conversationId,
    required this.senderFirebaseUid,
    required this.body,
  });
}

class ChatImageSendRequested extends ChatEvent {
  final String conversationId;
  final String firestoreConversationId;
  final String senderFirebaseUid;
  final Uint8List bytes;
  final String filename;
  const ChatImageSendRequested({
    required this.conversationId,
    required this.firestoreConversationId,
    required this.senderFirebaseUid,
    required this.bytes,
    required this.filename,
  });
}

class ChatLocationSendRequested extends ChatEvent {
  final String firestoreConversationId;
  final String conversationId;
  final String senderFirebaseUid;
  final double latitude;
  final double longitude;
  const ChatLocationSendRequested({
    required this.firestoreConversationId,
    required this.conversationId,
    required this.senderFirebaseUid,
    required this.latitude,
    required this.longitude,
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

