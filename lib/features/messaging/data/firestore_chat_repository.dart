import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';

class FirestoreChatRepository {
  final FirebaseFirestore _firestore;
  FirestoreChatRepository(this._firestore);

  Stream<List<MessageModel>> messagesStream(String firestoreConversationId) {
    return _firestore
        .collection('conversations')
        .doc(firestoreConversationId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageModel.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  Future<void> sendTextMessage({
    required String firestoreConversationId,
    required String senderFirebaseUid,
    required String body,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(firestoreConversationId)
        .collection('messages')
        .add({
      'senderId': senderFirebaseUid,
      'body': body,
      'imageUrl': null,
      'type': 'TEXT',
      'sentAt': DateTime.now().toIso8601String(),
      'readAt': null,
    });
  }

  Future<void> sendImageMessage({
    required String firestoreConversationId,
    required String senderFirebaseUid,
    required String imageUrl,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(firestoreConversationId)
        .collection('messages')
        .add({
      'senderId': senderFirebaseUid,
      'body': null,
      'imageUrl': imageUrl,
      'type': 'IMAGE',
      'sentAt': DateTime.now().toIso8601String(),
      'readAt': null,
    });
  }
}
