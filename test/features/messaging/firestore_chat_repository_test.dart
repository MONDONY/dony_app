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
}
