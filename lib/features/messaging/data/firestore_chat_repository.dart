import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';

/// Plafond de messages d'une conversation INQUIRY atteint (refus des règles).
class InquiryLimitReachedException implements Exception {
  @override
  String toString() => 'InquiryLimitReachedException';
}

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

  /// Nombre de messages déjà envoyés par le demandeur dans une conversation
  /// INQUIRY (`inquiryQuota/{id}.sent`), 0 tant que le document n'existe pas.
  Stream<int> inquirySentStream(String firestoreConversationId) {
    return _firestore
        .collection('inquiryQuota')
        .doc(firestoreConversationId)
        .snapshots()
        .map((snap) => (snap.data()?['sent'] as num?)?.toInt() ?? 0);
  }

  /// Demandeur (`askerId`, UID Firebase) et levée du quota (`quotaLifted`) du
  /// document de conversation INQUIRY, posés par le back. L'API ne sert pas le
  /// demandeur : c'est la seule façon de savoir si l'utilisateur est le
  /// demandeur (plafonné) ou le créateur de l'annonce. Flux réactif, repris à
  /// la reconnexion ; un champ absent ou d'un type inattendu donne `null` /
  /// `false`.
  Stream<({String? askerId, bool quotaLifted})> inquiryParentStream(
    String firestoreConversationId,
  ) => _conversationDoc(firestoreConversationId).map((data) {
    final asker = data?['askerId'];
    return (
      askerId: asker is String && asker.isNotEmpty ? asker : null,
      quotaLifted: data?['quotaLifted'] == true,
    );
  });

  Stream<Map<String, dynamic>?> _conversationDoc(String id) => _firestore
      .collection('conversations')
      .doc(id)
      .snapshots()
      .map((snap) => snap.data());

  /// [inquirySentBefore] non nul : message du demandeur dans une conversation
  /// INQUIRY sous quota. Les règles Firestore exigent alors, dans UN seul lot,
  /// le message à l'id `inq<n>` (n = nouvelle valeur de `sent`) et le compteur
  /// `inquiryQuota/{id} = {sent: n}`. Un refus `permission-denied` signifie
  /// que le plafond est atteint ([InquiryLimitReachedException]).
  Future<void> sendTextMessage({
    required String firestoreConversationId,
    required String senderFirebaseUid,
    required String body,
    String? replyToId,
    int? inquirySentBefore,
  }) async {
    final messages = _firestore
        .collection('conversations')
        .doc(firestoreConversationId)
        .collection('messages');
    final data = <String, Object?>{
      'senderId': senderFirebaseUid,
      'body': body,
      'imageUrl': null,
      'type': 'TEXT',
      'sentAt': DateTime.now().toUtc().toIso8601String(),
      'readAt': null,
      ..._replyTo(replyToId),
    };
    if (inquirySentBefore == null) {
      await messages.add(data);
      return;
    }
    final sent = inquirySentBefore + 1;
    final quota = _firestore
        .collection('inquiryQuota')
        .doc(firestoreConversationId);
    final batch = _firestore.batch()..set(messages.doc('inq$sent'), data);
    if (inquirySentBefore == 0) {
      batch.set(quota, {'sent': sent});
    } else {
      batch.update(quota, {'sent': sent});
    }
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw InquiryLimitReachedException();
      }
      rethrow;
    }
  }

  Future<void> sendLocationMessage({
    required String firestoreConversationId,
    required String senderFirebaseUid,
    required double latitude,
    required double longitude,
    String? replyToId,
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
          ..._replyTo(replyToId),
        });
  }

  /// Clé `replyToId` écrite seulement pour une réponse (FLUTTER-86) : un
  /// message ordinaire garde exactement l'ancien format, que les règles
  /// Firestore (liste blanche de clés) acceptent déjà.
  static Map<String, Object> _replyTo(String? replyToId) =>
      replyToId == null ? const {} : {'replyToId': replyToId};

  /// Message cité absent des 50 derniers chargés : relu à l'unité pour
  /// reconstituer la citation. `null` s'il n'existe pas (ou plus) ou si l'id
  /// n'a pas la forme d'un id de message (jamais de chemin arbitraire).
  Future<MessageModel?> getMessage(
    String firestoreConversationId,
    String messageId,
  ) async {
    if (!MessageModel.validReplyToId.hasMatch(messageId)) return null;
    final doc = await _firestore
        .collection('conversations')
        .doc(firestoreConversationId)
        .collection('messages')
        .doc(messageId)
        .get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return MessageModel.fromFirestore(doc.id, data);
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
    //
    // Filtré sur ce seul code : avaler toute erreur masquerait aussi de vrais
    // bugs (parsing, réseau) sans laisser de trace — seul permission-denied
    // est un état transitoire attendu ici.
    return _firestore
        .collection('userMeta')
        .doc(currentUserUid)
        .snapshots()
        .handleError(
          (_) {},
          test: (e) => e is FirebaseException && e.code == 'permission-denied',
        )
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
    return _conversationDoc(
      firestoreConversationId,
    ).map((data) => data?['deletedAt'] != null);
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
