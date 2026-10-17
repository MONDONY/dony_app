import 'dart:async';

import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/services/device_id_service.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/notifications/data/fcm_token_retry.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockDeviceIdService extends Mock implements DeviceIdService {}

class _MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class _MockLocalNotifications extends Mock
    implements FlutterLocalNotificationsPlugin {}

/// FLUTTER-R7 : au premier plan, les push étaient muettes sur iPhone. Le seul
/// délégué `UNUserNotificationCenter` (firebase_messaging) répondait « aucune
/// présentation », y compris pour la notification locale affichée par l'app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockFirebaseMessaging fcm;
  late _MockLocalNotifications local;
  late NotificationService service;

  setUpAll(() {
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const NotificationDetails());
  });

  setUp(() {
    fcm = _MockFirebaseMessaging();
    local = _MockLocalNotifications();
    when(
      () => local.initialize(
        any(),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => local.getNotificationAppLaunchDetails(),
    ).thenAnswer((_) async => null);
    when(
      () => local.show(
        any(),
        any(),
        any(),
        any(),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
    when(() => fcm.getInitialMessage()).thenAnswer((_) async => null);
    when(() => fcm.onTokenRefresh).thenAnswer((_) => const Stream.empty());
    when(
      () => fcm.setForegroundNotificationPresentationOptions(
        alert: any(named: 'alert'),
        badge: any(named: 'badge'),
        sound: any(named: 'sound'),
      ),
    ).thenAnswer((_) async {});

    service = NotificationService(
      _MockApiClient(),
      _MockNotificationRepository(),
      _MockDeviceIdService(),
      null,
      const FirebaseSessionProbe(),
      fcm,
      null,
      FcmTokenRetry(),
      local,
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    service.dispose();
  });

  RemoteMessage message() => const RemoteMessage(
    data: {'type': 'NEW_MESSAGE', 'conversationId': 'c1'},
    notification: RemoteNotification(title: 'Awa', body: 'Bonjour'),
  );

  test(
    'initialize pose les options de présentation au premier plan (iOS)',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await service.initialize();

      verify(
        () => fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        ),
      ).called(1);
    },
  );

  test('iOS : pas de notification locale, la bannière vient du système', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    service.testHandleForegroundMessage(message());

    verifyNever(
      () => local.show(
        any(),
        any(),
        any(),
        any(),
        payload: any(named: 'payload'),
      ),
    );
  });

  test('iOS : la push est toujours relayée aux écrans ouverts', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final received = <Map<String, dynamic>>[];
    final sub = service.foregroundPushStream.listen(received.add);
    addTearDown(sub.cancel);

    service.testHandleForegroundMessage(message());
    await Future<void>.delayed(Duration.zero);

    expect(received.single['type'], 'NEW_MESSAGE');
  });

  test('Android : notification locale toujours affichée', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    service.testHandleForegroundMessage(message());

    verify(
      () => local.show(
        any(),
        'Awa',
        'Bonjour',
        any(),
        payload: any(named: 'payload'),
      ),
    ).called(1);
  });
}
