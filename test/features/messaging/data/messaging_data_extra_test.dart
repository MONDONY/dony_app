import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/recording_dio.dart';

Map<String, dynamic> _conversationJson(String id) => {
  'id': id,
  'bidId': 'bid-$id',
  'firestoreConversationId': 'conv_$id',
  'otherParticipant': {'id': 'user-2', 'name': 'Fatou'},
  'hasUnread': false,
  'unreadCount': 0,
};

void main() {
  group('ConversationRepository', () {
    late RecordingApi api;
    late ConversationRepository repo;

    setUp(() {
      api = RecordingApi();
      repo = ConversationRepository(api.client);
    });

    test('getConversation et getByBidId lisent la conversation', () async {
      api.on('GET', '/conversations/c1', _conversationJson('c1'));
      api.on('GET', '/conversations/bid/bid-c2', _conversationJson('c2'));

      final byId = await repo.getConversation('c1');
      expect(byId.id, 'c1');
      expect(byId.otherParticipant.name, 'Fatou');

      final byBid = await repo.getByBidId('bid-c2');
      expect(byBid.firestoreConversationId, 'conv_c2');
    });

    test('updateLastMessage poste l’aperçu', () async {
      await repo.updateLastMessage('c1', 'Bonjour');
      expect(api.last.method, 'POST');
      expect(api.last.path, '/conversations/c1/last-message');
      expect(api.last.data, {'preview': 'Bonjour'});
    });

    test('restoreConversation rend la conversation restaurée', () async {
      api.on('POST', '/conversations/c1/restore', _conversationJson('c1'));
      expect((await repo.restoreConversation('c1')).id, 'c1');
    });

    test('delete, archive et unarchive appellent les bonnes routes', () async {
      await repo.deleteConversation('c1');
      await repo.archiveConversation('c1');
      await repo.unarchiveConversation('c1');
      expect(api.requests.map((r) => '${r.method} ${r.path}'), [
        'DELETE /conversations/c1',
        'POST /conversations/c1/archive',
        'POST /conversations/c1/unarchive',
      ]);
    });
  });

  group('FirestoreChatRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreChatRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = FirestoreChatRepository(firestore);
    });

    Future<void> addMessage(
      String id, {
      required String senderId,
      String? readAt,
      required String sentAt,
    }) => firestore
        .collection('conversations')
        .doc('conv_1')
        .collection('messages')
        .doc(id)
        .set({
          'senderId': senderId,
          'body': id,
          'type': 'TEXT',
          'sentAt': sentAt,
          'readAt': readAt,
        });

    test(
      'markMessagesRead marque seulement les messages reçus non lus',
      () async {
        await addMessage(
          'm1',
          senderId: 'other',
          sentAt: '2026-01-01T10:00:00Z',
        );
        await addMessage(
          'm2',
          senderId: 'other',
          sentAt: '2026-01-01T11:00:00Z',
          readAt: '2026-01-01T11:30:00Z',
        );
        await addMessage('m3', senderId: 'me', sentAt: '2026-01-01T12:00:00Z');

        await repo.markMessagesRead(
          firestoreConversationId: 'conv_1',
          currentUserUid: 'me',
        );

        final messages = firestore
            .collection('conversations')
            .doc('conv_1')
            .collection('messages');
        final m1 = (await messages.doc('m1').get()).data()!;
        final m2 = (await messages.doc('m2').get()).data()!;
        final m3 = (await messages.doc('m3').get()).data()!;
        expect(m1['readAt'], isA<String>());
        expect(DateTime.parse(m1['readAt'] as String).isUtc, isTrue);
        expect(m2['readAt'], '2026-01-01T11:30:00Z');
        expect(m3['readAt'], isNull);
      },
    );

    test('markMessagesRead ne fait rien sans message non lu', () async {
      await addMessage('m1', senderId: 'me', sentAt: '2026-01-01T10:00:00Z');
      await repo.markMessagesRead(
        firestoreConversationId: 'conv_1',
        currentUserUid: 'me',
      );
      final m1 = await firestore
          .collection('conversations')
          .doc('conv_1')
          .collection('messages')
          .doc('m1')
          .get();
      expect(m1.data()!['readAt'], isNull);
    });

    test('conversationDeletedStream suit deletedAt', () async {
      final doc = firestore.collection('conversations').doc('conv_1');
      await doc.set({'deletedAt': null});

      final values = <bool>[];
      final sub = repo.conversationDeletedStream('conv_1').listen(values.add);
      await pumpEventQueue();
      await doc.update({'deletedAt': '2026-01-02T00:00:00Z'});
      await pumpEventQueue();
      await sub.cancel();

      expect(values.first, isFalse);
      expect(values.last, isTrue);
    });

    test(
      'conversationDeletedStream : document absent = non supprimé',
      () async {
        expect(await repo.conversationDeletedStream('absent').first, isFalse);
      },
    );
  });
}
