import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// CollectionReference/DocumentReference/Query sont scellées côté cloud_firestore.
// Les mocker reste la seule façon de tester ce repository sans émulateur, et
// mocktail s'en accommode : l'avertissement est neutralisé sciemment.
// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreChatRepository repo;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repo = FirestoreChatRepository(fakeFirestore);
  });

  test('totalUnreadStream swallows a permission-denied stream error instead '
      'of crashing', () async {
    // Reproduces FLUTTER-3 (Sentry) : le token Auth pas encore propagé
    // pendant la vérification du numéro de téléphone fait planter le
    // listener userMeta en permission-denied, non rattrapé jusqu'à
    // PlatformDispatcher.onError. handleError() doit avaler l'erreur.
    final mockFirestore = MockFirebaseFirestore();
    final mockCollection = MockCollectionReference();
    final mockDoc = MockDocumentReference();

    when(() => mockFirestore.collection('userMeta')).thenReturn(mockCollection);
    when(() => mockCollection.doc('uid-1')).thenReturn(mockDoc);
    when(() => mockDoc.snapshots()).thenAnswer(
      (_) => Stream.error(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
    );

    final repoWithMockedAuthFailure = FirestoreChatRepository(mockFirestore);

    final events = await repoWithMockedAuthFailure
        .totalUnreadStream('uid-1')
        .toList();
    expect(events, isEmpty);
  });

  test('totalUnreadStream rethrows a non-permission-denied error instead of '
      'silently swallowing it', () async {
    // Le filtre ne doit avaler QUE permission-denied — toute autre erreur
    // (bug de parsing, panne réseau) doit rester visible plutôt que
    // disparaître en silence.
    final mockFirestore = MockFirebaseFirestore();
    final mockCollection = MockCollectionReference();
    final mockDoc = MockDocumentReference();

    when(() => mockFirestore.collection('userMeta')).thenReturn(mockCollection);
    when(() => mockCollection.doc('uid-1')).thenReturn(mockDoc);
    when(() => mockDoc.snapshots()).thenAnswer(
      (_) => Stream.error(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ),
    );

    final repoWithMockedFailure = FirestoreChatRepository(mockFirestore);

    await expectLater(
      repoWithMockedFailure.totalUnreadStream('uid-1'),
      emitsError(
        isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable'),
      ),
    );
  });

  test('totalUnreadStream emits 0 when no userMeta doc', () async {
    final result = await repo.totalUnreadStream('uid-1').first;
    expect(result, 0);
  });

  test('totalUnreadStream sums per-conversation unread fields', () async {
    await fakeFirestore.collection('userMeta').doc('uid-1').set({
      // Stale aggregate must be ignored — sum is the source of truth.
      'totalUnreadMessages': 99,
      'unread_conv_a': 2,
      'unread_conv_b': 1,
      'unread_conv_c': 0,
    });
    final result = await repo.totalUnreadStream('uid-1').first;
    expect(result, 3);
  });

  test(
    'totalUnreadStream returns 0 when only orphan totalUnreadMessages remains',
    () async {
      // Reproduces the bug seen on +33766334898: a stale aggregate from a
      // deleted conversation must not light up the badge.
      await fakeFirestore.collection('userMeta').doc('uid-1').set({
        'totalUnreadMessages': 4,
      });
      final result = await repo.totalUnreadStream('uid-1').first;
      expect(result, 0);
    },
  );

  test(
    'cleanupOrphanUnreadCounters zeroes unread_* keys not in valid set',
    () async {
      await fakeFirestore.collection('userMeta').doc('uid-1').set({
        'totalUnreadMessages': 7,
        'unread_conv_keep': 3,
        'unread_conv_orphan': 4,
      });
      await repo.cleanupOrphanUnreadCounters(
        currentUserUid: 'uid-1',
        validFirestoreIds: {'conv_keep'},
      );
      final doc = await fakeFirestore.collection('userMeta').doc('uid-1').get();
      expect(doc.data()?['unread_conv_keep'], 3);
      expect(doc.data()?['unread_conv_orphan'], 0);
      expect(doc.data()?['totalUnreadMessages'], 0);
    },
  );

  test(
    'perConversationUnreadStream returns map of non-zero unread convIds',
    () async {
      await fakeFirestore.collection('userMeta').doc('uid-1').set({
        'totalUnreadMessages': 5,
        'unread_conv_bid123': 3,
        'unread_conv_bid456': 2,
        'unread_conv_bid789': 0,
      });
      final result = await repo.perConversationUnreadStream('uid-1').first;
      expect(result, {'conv_bid123': 3, 'conv_bid456': 2});
    },
  );

  test(
    'markConversationRead resets unread for conversation and decrements total',
    () async {
      await fakeFirestore.collection('userMeta').doc('uid-1').set({
        'totalUnreadMessages': 5,
        'unread_conv_bid123': 3,
      });
      await repo.markConversationRead('conv_bid123', 'uid-1');
      final doc = await fakeFirestore.collection('userMeta').doc('uid-1').get();
      expect(doc.data()?['unread_conv_bid123'], 0);
      expect(doc.data()?['totalUnreadMessages'], 2);
    },
  );

  test(
    'markConversationRead is no-op when unread count is already 0',
    () async {
      await fakeFirestore.collection('userMeta').doc('uid-1').set({
        'totalUnreadMessages': 0,
        'unread_conv_bid123': 0,
      });
      await repo.markConversationRead('conv_bid123', 'uid-1');
      final doc = await fakeFirestore.collection('userMeta').doc('uid-1').get();
      expect(doc.data()?['totalUnreadMessages'], 0);
    },
  );

  test(
    'perConversationUnreadStream returns empty map when doc does not exist',
    () async {
      final result = await repo.perConversationUnreadStream('uid-no-doc').first;
      expect(result, <String, int>{});
    },
  );

  test('messagesStream emits empty list when no messages', () async {
    final result = await repo.messagesStream('conv-empty').first;
    expect(result, isEmpty);
  });

  test('messagesStream emits messages ordered by sentAt descending', () async {
    await fakeFirestore
        .collection('conversations')
        .doc('conv-1')
        .collection('messages')
        .add({
          'senderId': 'uid-a',
          'body': 'Bonjour',
          'imageUrl': null,
          'type': 'TEXT',
          'sentAt': '2026-04-30T10:00:00.000',
          'readAt': null,
        });
    final result = await repo.messagesStream('conv-1').first;
    expect(result, hasLength(1));
    expect(result.first.body, 'Bonjour');
    expect(result.first.senderId, 'uid-a');
  });

  test('sendTextMessage adds a TEXT message document', () async {
    await repo.sendTextMessage(
      firestoreConversationId: 'conv-send-text',
      senderFirebaseUid: 'uid-sender',
      body: 'Hello world',
    );
    final snap = await fakeFirestore
        .collection('conversations')
        .doc('conv-send-text')
        .collection('messages')
        .get();
    expect(snap.docs, hasLength(1));
    expect(snap.docs.first.data()['body'], 'Hello world');
    expect(snap.docs.first.data()['type'], 'TEXT');
    expect(snap.docs.first.data()['senderId'], 'uid-sender');
  });

  group('réponse à un message (FLUTTER-86)', () {
    Future<Map<String, dynamic>> onlyMessage(String conv) async {
      final snap = await fakeFirestore
          .collection('conversations')
          .doc(conv)
          .collection('messages')
          .get();
      expect(snap.docs, hasLength(1));
      return snap.docs.first.data();
    }

    test('message ordinaire : clé replyToId absente (ancien format)', () async {
      await repo.sendTextMessage(
        firestoreConversationId: 'c-plain',
        senderFirebaseUid: 'uid',
        body: 'Salut',
      );
      await repo.sendLocationMessage(
        firestoreConversationId: 'c-plain-loc',
        senderFirebaseUid: 'uid',
        latitude: 1,
        longitude: 2,
      );
      for (final conv in ['c-plain', 'c-plain-loc']) {
        final data = await onlyMessage(conv);
        expect(data.containsKey('replyToId'), isFalse, reason: conv);
      }
      expect((await onlyMessage('c-plain')).keys.toSet(), {
        'senderId',
        'body',
        'imageUrl',
        'type',
        'sentAt',
        'readAt',
      });
    });

    test(
      'réponse : seule la clé replyToId s’ajoute, jamais d’extrait',
      () async {
        await repo.sendTextMessage(
          firestoreConversationId: 'c-reply',
          senderFirebaseUid: 'uid',
          body: 'Oui',
          replyToId: 'abc123',
        );
        await repo.sendLocationMessage(
          firestoreConversationId: 'c-reply-loc',
          senderFirebaseUid: 'uid',
          latitude: 1,
          longitude: 2,
          replyToId: 'abc123',
        );
        final text = await onlyMessage('c-reply');
        expect(text['replyToId'], 'abc123');
        expect(text.keys.toSet(), {
          'senderId',
          'body',
          'imageUrl',
          'type',
          'sentAt',
          'readAt',
          'replyToId',
        });
        expect((await onlyMessage('c-reply-loc'))['replyToId'], 'abc123');
      },
    );

    test('getMessage : relit un message cité de la conversation', () async {
      await fakeFirestore
          .collection('conversations')
          .doc('c1')
          .collection('messages')
          .doc('old42')
          .set({
            'senderId': 'uid-a',
            'body': 'Ancien',
            'type': 'TEXT',
            'sentAt': '2026-10-01T10:00:00.000Z',
          });
      final m = await repo.getMessage('c1', 'old42');
      expect(m?.id, 'old42');
      expect(m?.body, 'Ancien');
    });

    test('getMessage : null si introuvable ou id hors forme', () async {
      expect(await repo.getMessage('c1', 'missing'), isNull);
      expect(await repo.getMessage('c1', '../x'), isNull);
      expect(await repo.getMessage('c1', ''), isNull);
    });
  });
}
