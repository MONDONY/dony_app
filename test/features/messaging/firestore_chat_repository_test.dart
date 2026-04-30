import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreChatRepository repo;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repo = FirestoreChatRepository(fakeFirestore);
  });

  test('totalUnreadStream emits 0 when no userMeta doc', () async {
    final result = await repo.totalUnreadStream('uid-1').first;
    expect(result, 0);
  });

  test('totalUnreadStream emits correct count from userMeta', () async {
    await fakeFirestore.collection('userMeta').doc('uid-1').set({
      'totalUnreadMessages': 3,
    });
    final result = await repo.totalUnreadStream('uid-1').first;
    expect(result, 3);
  });

  test('perConversationUnreadStream returns map of non-zero unread convIds', () async {
    await fakeFirestore.collection('userMeta').doc('uid-1').set({
      'totalUnreadMessages': 5,
      'unread_conv_bid123': 3,
      'unread_conv_bid456': 2,
      'unread_conv_bid789': 0,
    });
    final result = await repo.perConversationUnreadStream('uid-1').first;
    expect(result, {
      'conv_bid123': 3,
      'conv_bid456': 2,
    });
  });

  test('markConversationRead resets unread for conversation and decrements total', () async {
    await fakeFirestore.collection('userMeta').doc('uid-1').set({
      'totalUnreadMessages': 5,
      'unread_conv_bid123': 3,
    });
    await repo.markConversationRead('conv_bid123', 'uid-1');
    final doc = await fakeFirestore.collection('userMeta').doc('uid-1').get();
    expect(doc.data()?['unread_conv_bid123'], 0);
    expect(doc.data()?['totalUnreadMessages'], 2);
  });

  test('markConversationRead is no-op when unread count is already 0', () async {
    await fakeFirestore.collection('userMeta').doc('uid-1').set({
      'totalUnreadMessages': 0,
      'unread_conv_bid123': 0,
    });
    await repo.markConversationRead('conv_bid123', 'uid-1');
    final doc = await fakeFirestore.collection('userMeta').doc('uid-1').get();
    expect(doc.data()?['totalUnreadMessages'], 0);
  });

  test('perConversationUnreadStream returns empty map when doc does not exist', () async {
    final result = await repo.perConversationUnreadStream('uid-no-doc').first;
    expect(result, <String, int>{});
  });

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

  test('sendImageMessage adds an IMAGE message document', () async {
    await repo.sendImageMessage(
      firestoreConversationId: 'conv-send-img',
      senderFirebaseUid: 'uid-sender',
      imageUrl: 'https://s3.example.com/photo.jpg',
    );
    final snap = await fakeFirestore
        .collection('conversations')
        .doc('conv-send-img')
        .collection('messages')
        .get();
    expect(snap.docs, hasLength(1));
    expect(snap.docs.first.data()['type'], 'IMAGE');
    expect(snap.docs.first.data()['imageUrl'], 'https://s3.example.com/photo.jpg');
    expect(snap.docs.first.data()['body'], isNull);
  });
}
