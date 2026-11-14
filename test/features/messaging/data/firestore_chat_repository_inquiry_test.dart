import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

class _MockFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _MockSnap extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class _MockMetadata extends Mock implements SnapshotMetadata {}

/// Instantané du compteur, du serveur ou du cache local.
DocumentSnapshot<Map<String, dynamic>> _quotaSnap({
  required bool exists,
  required bool fromCache,
  int? sent,
}) {
  final snap = _MockSnap();
  final metadata = _MockMetadata();
  when(() => metadata.isFromCache).thenReturn(fromCache);
  when(() => snap.exists).thenReturn(exists);
  when(() => snap.metadata).thenReturn(metadata);
  when(() => snap.data()).thenReturn(sent == null ? null : {'sent': sent});
  return snap;
}

/// Dépôt dont le compteur `inquiryQuota/c1` rend [snaps].
FirestoreChatRepository _repoWithQuota(
  List<DocumentSnapshot<Map<String, dynamic>>> snaps,
) {
  final firestore = _MockFirestore();
  final collection = _MockCollection();
  final doc = _MockDoc();
  when(() => firestore.collection('inquiryQuota')).thenReturn(collection);
  when(() => collection.doc('c1')).thenReturn(doc);
  when(doc.snapshots).thenAnswer((_) => Stream.fromIterable(snaps));
  return FirestoreChatRepository(firestore);
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

  group('inquirySentStream hors ligne (revue m7)', () {
    test('compteur absent du cache local : ignoré, jamais un faux 0', () async {
      final repo = _repoWithQuota([
        _quotaSnap(exists: false, fromCache: true),
        _quotaSnap(exists: true, fromCache: false, sent: 4),
      ]);
      expect(await repo.inquirySentStream('c1').toList(), [4]);
    });

    test('compteur absent côté serveur : 0', () async {
      final repo = _repoWithQuota([
        _quotaSnap(exists: false, fromCache: false),
      ]);
      expect(await repo.inquirySentStream('c1').toList(), [0]);
    });

    test('compteur présent dans le cache (écriture locale) : gardé', () async {
      final repo = _repoWithQuota([
        _quotaSnap(exists: true, fromCache: true, sent: 2),
      ]);
      expect(await repo.inquirySentStream('c1').toList(), [2]);
    });
  });

  group('inquiryParentStream', () {
    Future<
      List<({String? askerId, bool quotaLifted, bool exists, bool fromCache})>
    >
    collect(Map<String, Object?>? data) async {
      if (data != null) {
        await firestore.collection('conversations').doc('c1').set(data);
      }
      final out = await repo
          .inquiryParentStream('c1')
          .take(1)
          .toList()
          .timeout(const Duration(seconds: 2));
      return out;
    }

    test('askerId et quotaLifted lus', () async {
      final r = await collect({'askerId': 'u9', 'quotaLifted': true});
      expect(r.single.askerId, 'u9');
      expect(r.single.quotaLifted, isTrue);
      expect(r.single.exists, isTrue);
    });

    test('champs absents : askerId nul, quota actif', () async {
      final r = await collect({'kind': 'INQUIRY'});
      expect(r.single.askerId, isNull);
      expect(r.single.quotaLifted, isFalse);
    });

    test('askerId vide ou non texte : nul', () async {
      expect((await collect({'askerId': ''})).single.askerId, isNull);
      await firestore.collection('conversations').doc('c1').delete();
      expect((await collect({'askerId': 42})).single.askerId, isNull);
    });

    test('quotaLifted non booléen : faux', () async {
      final r = await collect({'askerId': 'u1', 'quotaLifted': 'true'});
      expect(r.single.quotaLifted, isFalse);
    });

    test(
      'document absent : un événement sans demandeur, exists faux',
      () async {
        final r = await collect(null);
        expect(r.single.askerId, isNull);
        expect(r.single.exists, isFalse);
        expect(r.single.fromCache, isFalse);
      },
    );

    test('suit les changements du document', () async {
      final seen = <bool>[];
      await firestore.collection('conversations').doc('c1').set({
        'askerId': 'u1',
        'quotaLifted': false,
      });
      final sub = repo
          .inquiryParentStream('c1')
          .listen((e) => seen.add(e.quotaLifted));
      await Future<void>.delayed(Duration.zero);
      await firestore.collection('conversations').doc('c1').update({
        'quotaLifted': true,
      });
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(seen, [false, true]);
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
