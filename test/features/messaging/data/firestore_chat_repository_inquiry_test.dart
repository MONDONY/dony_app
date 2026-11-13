import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lot dont le commit est refusé comme le ferait une règle Firestore.
class _DenyingBatch implements WriteBatch {
  @override
  Future<void> commit() async => throw FirebaseException(
    plugin: 'cloud_firestore',
    code: 'permission-denied',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _DenyingFirestore extends FakeFirebaseFirestore {
  @override
  WriteBatch batch() => _DenyingBatch();
}

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreChatRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestoreChatRepository(firestore);
  });

  DocumentReference<Map<String, dynamic>> msg(String id) => firestore
      .collection('conversations')
      .doc('c1')
      .collection('messages')
      .doc(id);
  DocumentReference<Map<String, dynamic>> quota() =>
      firestore.collection('inquiryQuota').doc('c1');

  Future<void> send(int? before, {String? replyToId}) => repo.sendTextMessage(
    firestoreConversationId: 'c1',
    senderFirebaseUid: 'u1',
    body: 'Salut',
    replyToId: replyToId,
    inquirySentBefore: before,
  );

  group('envoi avec compteur', () {
    test('à 0 : message inq1 et compteur créé à {sent: 1}', () async {
      await send(0);
      final m = await msg('inq1').get();
      expect(m.exists, isTrue);
      expect(m.data()!.keys.toSet(), {
        'senderId',
        'body',
        'imageUrl',
        'type',
        'sentAt',
        'readAt',
      });
      expect(m.data()!['senderId'], 'u1');
      expect(m.data()!['type'], 'TEXT');
      expect(m.data()!['imageUrl'], isNull);
      expect(m.data()!['readAt'], isNull);
      expect((await quota().get()).data(), {'sent': 1});
    });

    test('à 4 : message inq5, compteur mis à jour à 5', () async {
      await quota().set({'sent': 4});
      await send(4);
      expect((await msg('inq5').get()).exists, isTrue);
      expect((await quota().get()).data(), {'sent': 5});
    });

    test('à 9 : message inq10, compteur à 10', () async {
      await quota().set({'sent': 9});
      await send(9);
      expect((await msg('inq10').get()).exists, isTrue);
      expect((await quota().get()).data(), {'sent': 10});
    });

    test('replyToId est conservé dans le message', () async {
      await send(0, replyToId: 'm0');
      expect((await msg('inq1').get()).data()!['replyToId'], 'm0');
    });

    test('permission-denied devient InquiryLimitReachedException', () async {
      final denying = FirestoreChatRepository(_DenyingFirestore());
      expect(
        () => denying.sendTextMessage(
          firestoreConversationId: 'c1',
          senderFirebaseUid: 'u1',
          body: 'Salut',
          inquirySentBefore: 3,
        ),
        throwsA(isA<InquiryLimitReachedException>()),
      );
    });

    test('une autre erreur Firestore n\'est pas transformée', () async {
      final repoWithBatchError = FirestoreChatRepository(
        _UnavailableFirestore(),
      );
      expect(
        () => repoWithBatchError.sendTextMessage(
          firestoreConversationId: 'c1',
          senderFirebaseUid: 'u1',
          body: 'Salut',
          inquirySentBefore: 3,
        ),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('sans compteur (non-régression)', () {
    test('un seul add, clés exactes inchangées', () async {
      await send(null);
      final snap = await firestore
          .collection('conversations')
          .doc('c1')
          .collection('messages')
          .get();
      expect(snap.docs, hasLength(1));
      expect(snap.docs.single.id, isNot(startsWith('inq')));
      expect(snap.docs.single.data().keys.toSet(), {
        'senderId',
        'body',
        'imageUrl',
        'type',
        'sentAt',
        'readAt',
      });
      expect((await quota().get()).exists, isFalse);
    });

    test('avec replyToId : clé supplémentaire replyToId', () async {
      await send(null, replyToId: 'm0');
      final snap = await firestore
          .collection('conversations')
          .doc('c1')
          .collection('messages')
          .get();
      expect(snap.docs.single.data().keys.toSet(), {
        'senderId',
        'body',
        'imageUrl',
        'type',
        'sentAt',
        'readAt',
        'replyToId',
      });
    });
  });

  group('inquirySentStream', () {
    test('émet 0 si absent puis les valeurs suivantes', () async {
      final values = <int>[];
      final sub = repo.inquirySentStream('c1').listen(values.add);
      await Future<void>.delayed(Duration.zero);
      await send(0);
      await Future<void>.delayed(Duration.zero);
      await send(1);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(values, [0, 1, 2]);
    });
  });
}

class _UnavailableBatch implements WriteBatch {
  @override
  Future<void> commit() async =>
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _UnavailableFirestore extends FakeFirebaseFirestore {
  @override
  WriteBatch batch() => _UnavailableBatch();
}
