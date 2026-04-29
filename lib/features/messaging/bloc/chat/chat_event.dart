import 'dart:typed_data';

abstract class ChatEvent {
  const ChatEvent();
}

class ChatSubscribeRequested extends ChatEvent {
  final String firestoreConversationId;
  const ChatSubscribeRequested(this.firestoreConversationId);
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
