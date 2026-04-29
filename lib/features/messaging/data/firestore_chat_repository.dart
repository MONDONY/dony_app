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

  /// Stream of total unread message count for [currentUserUid].
  Stream<int> totalUnreadStream(String currentUserUid) {
    return _firestore
        .collection('userMeta')
        .doc(currentUserUid)
        .snapshots()
        .map((doc) => (doc.data()?['totalUnreadMessages'] as int?) ?? 0);
  }

  /// Stream of per-conversation unread counts for [currentUserUid].
  /// Keys are Firestore conversation IDs (e.g. "conv_<bidId>").
  /// Only conversations with count > 0 are included.
  Stream<Map<String, int>> perConversationUnreadStream(String currentUserUid) {
    return _firestore
        .collection('userMeta')
        .doc(currentUserUid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return <String, int>{};
          final data = doc.data()!;
          return Map.fromEntries(
            data.entries
                .where((e) =>
                    e.key.startsWith('unread_') && (e.value as int? ?? 0) > 0)
                .map((e) => MapEntry(
                      e.key.replaceFirst('unread_', ''),
                      (e.value as num).toInt(),
                    )),
          );
        });
  }

  /// Resets the unread count for [firestoreConvId] and decrements the total.
  Future<void> markConversationRead(
      String firestoreConvId, String currentUserUid) async {
    final doc = await _firestore
        .collection('userMeta')
        .doc(currentUserUid)
        .get();

    final currentCount =
        (doc.data()?['unread_$firestoreConvId'] as int?) ?? 0;
    if (currentCount <= 0) return;

    await _firestore.collection('userMeta').doc(currentUserUid).update({
      'unread_$firestoreConvId': 0,
      'totalUnreadMessages': FieldValue.increment(-currentCount),
    });
  }
}
