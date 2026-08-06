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
        .map(
          (snap) => snap.docs
              .map((doc) => MessageModel.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
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
          'sentAt': DateTime.now().toUtc().toIso8601String(),
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
          'sentAt': DateTime.now().toUtc().toIso8601String(),
          'readAt': null,
        });
  }

  Future<void> sendLocationMessage({
    required String firestoreConversationId,
    required String senderFirebaseUid,
    required double latitude,
    required double longitude,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(firestoreConversationId)
        .collection('messages')
        .add({
          'senderId': senderFirebaseUid,
          'body': null,
          'imageUrl': null,
          'type': 'LOCATION',
          'latitude': latitude,
          'longitude': longitude,
          'sentAt': DateTime.now().toUtc().toIso8601String(),
          'readAt': null,
        });
  }

  /// Marks all messages from the other participant as read by setting [readAt].
  /// Fetches up to 50 recent messages and updates in a batch.
  Future<void> markMessagesRead({
    required String firestoreConversationId,
    required String currentUserUid,
  }) async {
    final snap = await _firestore
        .collection('conversations')
        .doc(firestoreConversationId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(50)
        .get();

    final unread = snap.docs
        .where(
          (d) =>
              d.data()['senderId'] != currentUserUid &&
              d.data()['readAt'] == null,
        )
        .toList();
    if (unread.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {
        'readAt': DateTime.now().toUtc().toIso8601String(),
      });
    }
    await batch.commit();
  }

  Stream<int> totalUnreadStream(String currentUserUid) {
    // Compute the total from per-conversation `unread_*` fields rather than
    // the stored `totalUnreadMessages` aggregate. The aggregate can drift
    // (e.g. when a conversation is deleted while still holding unread
    // messages), so summing the source-of-truth fields self-heals the badge.
    //
    // handleError : seul consommateur (badge Messages de main_shell.dart), pas
    // de garde équivalent au onError de perConversationUnreadStream côté
    // appelant. Sans lui, un token Auth pas encore propagé (ex: pendant la
    // vérification du numéro de téléphone) fait planter le stream en
    // permission-denied côté Firestore — non rattrapé, ça remonte jusqu'à
    // PlatformDispatcher.onError (crash fatal Sentry FLUTTER-3).
    return _firestore
        .collection('userMeta')
        .doc(currentUserUid)
        .snapshots()
        .handleError((_) {})
        .map((doc) {
          final data = doc.data();
          if (data == null) return 0;
          var total = 0;
          for (final entry in data.entries) {
            if (!entry.key.startsWith('unread_')) continue;
            final value = entry.value;
            if (value is num && value > 0) total += value.toInt();
          }
          return total;
        });
  }

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
                .where(
                  (e) =>
                      e.key.startsWith('unread_') && (e.value as int? ?? 0) > 0,
                )
                .map(
                  (e) => MapEntry(
                    e.key.replaceFirst('unread_', ''),
                    (e.value as num).toInt(),
                  ),
                ),
          );
        });
  }

  Stream<bool> conversationDeletedStream(String firestoreConversationId) {
    return _firestore
        .collection('conversations')
        .doc(firestoreConversationId)
        .snapshots()
        .map((snap) => snap.data()?['deletedAt'] != null);
  }

  /// Zero out per-conversation unread counters whose firestoreConversationId
  /// is not in [validFirestoreIds]. Used after loading the conversation list
  /// to self-heal stale `unread_*` fields left behind by deletions that
  /// happened before the cleanup logic was in place.
  Future<void> cleanupOrphanUnreadCounters({
    required String currentUserUid,
    required Set<String> validFirestoreIds,
  }) async {
    if (currentUserUid.isEmpty) return;
    final docRef = _firestore.collection('userMeta').doc(currentUserUid);
    final snap = await docRef.get();
    final data = snap.data();
    if (data == null) return;

    final updates = <String, Object?>{};
    for (final entry in data.entries) {
      if (!entry.key.startsWith('unread_')) continue;
      final value = entry.value;
      if (value is! num || value <= 0) continue;
      final convId = entry.key.substring('unread_'.length);
      if (!validFirestoreIds.contains(convId)) {
        updates[entry.key] = 0;
      }
    }
    if (updates.isEmpty) return;
    // Reset `totalUnreadMessages` too — it will be recomputed by future writes,
    // and `totalUnreadStream` no longer reads it directly.
    updates['totalUnreadMessages'] = 0;
    await docRef.update(updates);
  }

  Future<void> markConversationRead(
    String firestoreConvId,
    String currentUserUid,
  ) async {
    final doc = await _firestore
        .collection('userMeta')
        .doc(currentUserUid)
        .get();

    final currentCount = (doc.data()?['unread_$firestoreConvId'] as int?) ?? 0;
    if (currentCount <= 0) return;

    await _firestore.collection('userMeta').doc(currentUserUid).update({
      'unread_$firestoreConvId': 0,
      'totalUnreadMessages': FieldValue.increment(-currentCount),
    });
  }
}
