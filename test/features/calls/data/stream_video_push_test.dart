import 'package:dony/features/calls/data/stream_video_push.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reconnaît un push Stream Video', () {
    expect(isStreamVideoPush({'sender': 'stream.video', 'type': 'call.ring'}), isTrue);
    expect(isStreamVideoPush({'type': 'NEW_MESSAGE'}), isFalse);
    expect(isStreamVideoPush(const {}), isFalse);
  });

  group('premier plan', () {
    test('push Stream : relayé au client d\'appel, et signalé comme traité', () async {
      final received = <Map<String, dynamic>>[];
      final handled = dispatchStreamVideoPush({'sender': 'stream.video'}, (data) async => received.add(data));
      await Future<void>.delayed(Duration.zero);
      expect(handled, isTrue);
      expect(received, hasLength(1));
    });

    test('push Stream sans client d\'appel : traité quand même (pas de notification Yadony)', () {
      expect(dispatchStreamVideoPush({'sender': 'stream.video'}, null), isTrue);
    });

    test('autre push : laissé au chemin habituel', () {
      var called = false;
      final handled = dispatchStreamVideoPush({'type': 'NEW_MESSAGE'}, (_) async => called = true);
      expect(handled, isFalse);
      expect(called, isFalse);
    });
  });

  group('arrière-plan', () {
    late StreamVideoPushHandler previous;
    setUp(() => previous = backgroundStreamVideoPushHandler);
    tearDown(() => backgroundStreamVideoPushHandler = previous);

    test('push Stream : délégué au gestionnaire de sonnerie', () async {
      final received = <Map<String, dynamic>>[];
      backgroundStreamVideoPushHandler = (data) async => received.add(data);

      await firebaseMessagingBackgroundHandler(const RemoteMessage(data: {'sender': 'stream.video'}));

      expect(received, hasLength(1));
    });

    test('push Yadony : jamais envoyé au gestionnaire Stream', () async {
      final received = <Map<String, dynamic>>[];
      backgroundStreamVideoPushHandler = (data) async => received.add(data);

      await firebaseMessagingBackgroundHandler(const RemoteMessage(data: {'type': 'NEW_MESSAGE'}));

      expect(received, isEmpty);
    });
  });
}
