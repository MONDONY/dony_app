import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/services/device_id_service.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockDeviceIdService extends Mock implements DeviceIdService {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient apiClient;
  late MockNotificationRepository repository;
  late MockDeviceIdService deviceIdService;
  late NotificationService service;

  setUp(() {
    apiClient = MockApiClient();
    repository = MockNotificationRepository();
    deviceIdService = MockDeviceIdService();
    service = NotificationService(apiClient, repository, deviceIdService);
  });

  group('NotificationService._uploadToken', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
      when(() => apiClient.dio).thenReturn(mockDio);
      when(
        () => deviceIdService.getDeviceId(),
      ).thenAnswer((_) async => 'test-device-id-uuid');
    });

    test(
      'sends fcmToken, deviceId, deviceName and platform to the endpoint',
      () async {
        when(
          () => mockDio.put('/auth/me/fcm-token', data: any(named: 'data')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/auth/me/fcm-token'),
            statusCode: 200,
          ),
        );

        await service.testUploadToken('test-fcm-token');

        final captured = verify(
          () => mockDio.put(
            '/auth/me/fcm-token',
            data: captureAny(named: 'data'),
          ),
        ).captured;

        final body = captured.first as Map<String, dynamic>;
        expect(body['fcmToken'], 'test-fcm-token');
        expect(body['deviceId'], 'test-device-id-uuid');
        expect(body.containsKey('deviceName'), isTrue);
        expect(body['platform'], anyOf('ios', 'android'));
      },
    );

    test('swallows errors silently when upload fails', () async {
      when(
        () => mockDio.put('/auth/me/fcm-token', data: any(named: 'data')),
      ).thenThrow(Exception('network error'));

      await expectLater(service.testUploadToken('test-fcm-token'), completes);
    });
  });

  group('NotificationService._ackIfCritical', () {
    test('sends ACK for PAYMENT_RELEASED', () async {
      when(() => repository.ack('notif-42')).thenAnswer((_) async {});

      await service.testAckIfCritical({
        'type': 'PAYMENT_RELEASED',
        'notificationId': 'notif-42',
      });

      verify(() => repository.ack('notif-42')).called(1);
    });

    test('sends ACK for DELIVERY_CONFIRMED', () async {
      when(() => repository.ack('notif-43')).thenAnswer((_) async {});

      await service.testAckIfCritical({
        'type': 'DELIVERY_CONFIRMED',
        'notificationId': 'notif-43',
      });

      verify(() => repository.ack('notif-43')).called(1);
    });

    test('sends ACK for DISPUTE_OPENED', () async {
      when(() => repository.ack('notif-44')).thenAnswer((_) async {});

      await service.testAckIfCritical({
        'type': 'DISPUTE_OPENED',
        'notificationId': 'notif-44',
      });

      verify(() => repository.ack('notif-44')).called(1);
    });

    test('does NOT send ACK for non-critical type (BID_ACCEPTED)', () async {
      await service.testAckIfCritical({
        'type': 'BID_ACCEPTED',
        'notificationId': 'notif-45',
      });

      verifyNever(() => repository.ack(any()));
    });

    test('does NOT send ACK when notificationId is missing', () async {
      await service.testAckIfCritical({'type': 'PAYMENT_RELEASED'});

      verifyNever(() => repository.ack(any()));
    });

    test('does NOT send ACK when type is missing', () async {
      await service.testAckIfCritical({'notificationId': 'notif-46'});

      verifyNever(() => repository.ack(any()));
    });

    test('swallows ACK errors silently', () async {
      when(() => repository.ack(any())).thenThrow(Exception('network error'));

      // Must not throw
      await expectLater(
        service.testAckIfCritical({
          'type': 'PAYMENT_RELEASED',
          'notificationId': 'notif-47',
        }),
        completes,
      );
    });
  });

  // Valid UUIDs for routing tests — the service validates IDs with _isUuid()
  // before embedding them in route paths.
  const annId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
  const bidId = 'b1b2c3d4-e5f6-7890-abcd-ef1234567890';
  const threadId = 'c1b2c3d4-e5f6-7890-abcd-ef1234567890';

  group('NotificationService.resolveFcmToken', () {
    // Régression : sur iOS, getToken() renvoie null tant qu'APNs n'a pas
    // répondu. uploadCurrentToken part de authStateChanges, déclenché dès la
    // restauration de session au démarrage — donc avant l'inscription APNs. Le
    // jeton null était ignoré en silence, l'appareil n'était jamais enregistré
    // et l'iPhone ne recevait plus aucune notification, sans trace nulle part.
    test('iOS : attend le jeton APNs avant de demander le jeton FCM', () async {
      var apnsCalls = 0;
      final token = await NotificationService.resolveFcmToken(
        isIOS: true,
        // APNs ne répond qu'à la 3ᵉ tentative, comme au démarrage réel.
        getApnsToken: () async {
          apnsCalls++;
          return apnsCalls < 3 ? null : 'apns-token';
        },
        getFcmToken: () async => 'fcm-token',
        retryDelay: Duration.zero,
      );

      expect(token, 'fcm-token');
      expect(apnsCalls, 3);
    });

    test('iOS : abandonne après maxAttempts sans boucler indéfiniment', () async {
      var apnsCalls = 0;
      final token = await NotificationService.resolveFcmToken(
        isIOS: true,
        getApnsToken: () async {
          apnsCalls++;
          return null;
        },
        getFcmToken: () async => null,
        maxAttempts: 4,
        retryDelay: Duration.zero,
      );

      expect(token, isNull);
      expect(apnsCalls, 4);
    });

    test('Android : ne consulte jamais APNs', () async {
      var apnsCalls = 0;
      final token = await NotificationService.resolveFcmToken(
        isIOS: false,
        getApnsToken: () async {
          apnsCalls++;
          return null;
        },
        getFcmToken: () async => 'fcm-token',
        retryDelay: Duration.zero,
      );

      expect(token, 'fcm-token');
      expect(apnsCalls, 0);
    });
  });

  group('NotificationService.formatAndroidName', () {
    test('préfixe le fabricant quand le modèle ne commence pas par lui', () {
      expect(
        NotificationService.formatAndroidName('xiaomi', '25028RN03Y'),
        'Xiaomi 25028RN03Y',
      );
    });

    test(
      'ne duplique pas le fabricant quand le modèle commence déjà par lui',
      () {
        expect(
          NotificationService.formatAndroidName(
            'Samsung',
            'Samsung Galaxy S22',
          ),
          'Samsung Galaxy S22',
        );
      },
    );

    test('retourne le modèle seul quand le fabricant est vide', () {
      expect(NotificationService.formatAndroidName('', 'Pixel 7'), 'Pixel 7');
    });

    test('ignore la casse pour la détection de duplication', () {
      expect(
        NotificationService.formatAndroidName('SAMSUNG', 'samsung galaxy a54'),
        'samsung galaxy a54',
      );
    });

    test('capitalise la première lettre du fabricant', () {
      expect(
        NotificationService.formatAndroidName('google', 'Pixel 8 Pro'),
        'Google Pixel 8 Pro',
      );
    });

    test('gère les espaces superflus dans manufacturer et model', () {
      expect(
        NotificationService.formatAndroidName('  OnePlus  ', '  Nord 3  '),
        'OnePlus Nord 3',
      );
    });
  });

  group('NotificationService._routeForMessage', () {
    test('BID_CREATED routes to announcement bids page', () {
      expect(
        service.testRouteForMessage({
          'type': 'BID_CREATED',
          'announcementId': annId,
        }),
        '/announcements/$annId/bids',
      );
    });

    test('BID_ACCEPTED routes to bid detail', () {
      expect(
        service.testRouteForMessage({'type': 'BID_ACCEPTED', 'bidId': bidId}),
        '/bids/$bidId',
      );
    });

    test('BID_REJECTED routes to bid detail', () {
      expect(
        service.testRouteForMessage({'type': 'BID_REJECTED', 'bidId': bidId}),
        '/bids/$bidId',
      );
    });

    test('BID_REJECTED with valid cancellationId routes to rematch screen', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      expect(
        service.testRouteForMessage({
          'type': 'BID_REJECTED',
          'bidId': bidId,
          'cancellationId': uuid,
        }),
        '/cancellations/$uuid/rematch',
      );
    });

    test(
      'BID_REJECTED with non-UUID cancellationId falls back to bid detail',
      () {
        expect(
          service.testRouteForMessage({
            'type': 'BID_REJECTED',
            'bidId': bidId,
            'cancellationId': '../../evil',
          }),
          '/bids/$bidId',
        );
      },
    );

    test(
      'BID_REJECTED with valid cancellationId and no bidId routes to rematch screen',
      () {
        const uuid = '123e4567-e89b-12d3-a456-426614174000';
        expect(
          service.testRouteForMessage({
            'type': 'BID_REJECTED',
            'cancellationId': uuid,
          }),
          '/cancellations/$uuid/rematch',
        );
      },
    );

    test('automation_capacity_free routes to owner trip detail', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      expect(
        service.testRouteForMessage({
          'type': 'automation_capacity_free',
          'announcementId': uuid,
        }),
        '/announcements/$uuid/trip',
      );
    });

    test('automation_last_minute routes to bid detail', () {
      expect(
        service.testRouteForMessage({
          'type': 'automation_last_minute',
          'bidId': bidId,
        }),
        '/bids/$bidId',
      );
    });

    test('automation_loyal_sender routes to public trip detail', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      expect(
        service.testRouteForMessage({
          'type': 'automation_loyal_sender',
          'announcementId': uuid,
        }),
        '/traveler/$uuid',
      );
    });

    test('DELIVERY_CONFIRMED routes to bid detail', () {
      expect(
        service.testRouteForMessage({
          'type': 'DELIVERY_CONFIRMED',
          'bidId': bidId,
        }),
        '/bids/$bidId',
      );
    });

    test('PAYMENT_RELEASED routes to bid detail', () {
      expect(
        service.testRouteForMessage({
          'type': 'PAYMENT_RELEASED',
          'bidId': bidId,
        }),
        '/bids/$bidId',
      );
    });

    test('DISPUTE_OPENED routes to bid detail', () {
      expect(
        service.testRouteForMessage({'type': 'DISPUTE_OPENED', 'bidId': bidId}),
        '/bids/$bidId',
      );
    });

    test('TRIP_CANCELLED without any id falls back to shipments history', () {
      expect(
        service.testRouteForMessage({'type': 'TRIP_CANCELLED'}),
        '/profile/shipments/history',
      );
    });

    test(
      'TRIP_CANCELLED with valid cancellationId routes to rematch screen',
      () {
        const uuid = '123e4567-e89b-12d3-a456-426614174000';
        expect(
          service.testRouteForMessage({
            'type': 'TRIP_CANCELLED',
            'cancellationId': uuid,
          }),
          '/cancellations/$uuid/rematch',
        );
      },
    );

    test(
      'TRIP_CANCELLED with non-UUID cancellationId falls back to shipments history',
      () {
        expect(
          service.testRouteForMessage({
            'type': 'TRIP_CANCELLED',
            'cancellationId': 'not-a-uuid',
          }),
          '/profile/shipments/history',
        );
      },
    );

    test('TRIP_CANCELLED with bidId only routes to bid detail', () {
      expect(
        service.testRouteForMessage({'type': 'TRIP_CANCELLED', 'bidId': bidId}),
        '/bids/$bidId',
      );
    });

    test('unknown type returns null', () {
      expect(service.testRouteForMessage({'type': 'UNKNOWN'}), isNull);
    });

    test('BID_CREATED without announcementId returns null', () {
      expect(service.testRouteForMessage({'type': 'BID_CREATED'}), isNull);
    });

    test('BID_ACCEPTED without bidId returns null', () {
      expect(service.testRouteForMessage({'type': 'BID_ACCEPTED'}), isNull);
    });

    test('NEW_MESSAGE routes to /messages', () {
      expect(service.testRouteForMessage({'type': 'NEW_MESSAGE'}), '/messages');
    });

    test('negotiation_started routes to thread page', () {
      expect(
        service.testRouteForMessage({
          'type': 'negotiation_started',
          'threadId': threadId,
        }),
        '/negotiations/$threadId',
      );
    });

    test('negotiation_counter routes to thread page', () {
      expect(
        service.testRouteForMessage({
          'type': 'negotiation_counter',
          'threadId': threadId,
        }),
        '/negotiations/$threadId',
      );
    });

    test('negotiation_awaiting_trip routes to thread page', () {
      expect(
        service.testRouteForMessage({
          'type': 'negotiation_awaiting_trip',
          'threadId': threadId,
        }),
        '/negotiations/$threadId',
      );
    });

    test('negotiation_awaiting_payment routes to thread page', () {
      expect(
        service.testRouteForMessage({
          'type': 'negotiation_awaiting_payment',
          'threadId': threadId,
        }),
        '/negotiations/$threadId',
      );
    });

    test('negotiation_started without threadId returns null', () {
      expect(
        service.testRouteForMessage({'type': 'negotiation_started'}),
        isNull,
      );
    });

    test('request_accepted routes to thread page', () {
      expect(
        service.testRouteForMessage({
          'type': 'request_accepted',
          'threadId': threadId,
        }),
        '/negotiations/$threadId',
      );
    });

    test(
      'TRAVELER_NEW_ANNOUNCEMENT routes to traveler announcement detail',
      () {
        const uuid = '123e4567-e89b-12d3-a456-426614174000';
        expect(
          service.testRouteForMessage({
            'type': 'TRAVELER_NEW_ANNOUNCEMENT',
            'announcementId': uuid,
          }),
          '/traveler/$uuid',
        );
      },
    );

    test(
      'TRAVELER_NEW_ANNOUNCEMENT without valid announcementId returns null',
      () {
        expect(
          service.testRouteForMessage({'type': 'TRAVELER_NEW_ANNOUNCEMENT'}),
          isNull,
        );
        expect(
          service.testRouteForMessage({
            'type': 'TRAVELER_NEW_ANNOUNCEMENT',
            'announcementId': 'not-a-uuid',
          }),
          isNull,
        );
      },
    );

    test('CORRIDOR_ALERT routes to the matching trip detail', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      expect(
        service.testRouteForMessage({
          'type': 'CORRIDOR_ALERT',
          'announcementId': uuid,
        }),
        '/traveler/$uuid',
      );
    });

    test('CORRIDOR_ALERT without valid announcementId returns null', () {
      expect(service.testRouteForMessage({'type': 'CORRIDOR_ALERT'}), isNull);
      expect(
        service.testRouteForMessage({
          'type': 'CORRIDOR_ALERT',
          'announcementId': 'not-a-uuid',
        }),
        isNull,
      );
    });

    test('PACKAGE_MATCH routes to the matching package request detail', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      expect(
        service.testRouteForMessage({
          'type': 'PACKAGE_MATCH',
          'requestId': uuid,
        }),
        '/package-requests/$uuid/public',
      );
    });

    test('PACKAGE_MATCH without valid requestId returns null', () {
      expect(service.testRouteForMessage({'type': 'PACKAGE_MATCH'}), isNull);
      expect(
        service.testRouteForMessage({
          'type': 'PACKAGE_MATCH',
          'requestId': 'not-a-uuid',
        }),
        isNull,
      );
    });
  });

  // Le handler d'arrière-plan tourne dans un isolate sans GetIt ni ApiClient :
  // il refait l'appel à la main. Sans cet ACK, le backend envoyait un SMS 60 s
  // après chaque notification critique non ouverte, alors que le push était
  // bien arrivé.
  group('ackCriticalFromBackground', () {
    late MockDio dio;

    setUp(() {
      dio = MockDio();
      when(
        () => dio.post<void>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (invocation) async => Response<void>(
          requestOptions: RequestOptions(
            path: invocation.positionalArguments.first as String,
          ),
          statusCode: 204,
        ),
      );
    });

    Future<void> run(Map<String, dynamic> data, {String? idToken = 'jwt'}) =>
        ackCriticalFromBackground(
          data,
          dioOverride: dio,
          idTokenOverride: () async => idToken,
        );

    test('accuse réception d’une notification critique', () async {
      await run({'type': 'PAYMENT_RELEASED', 'notificationId': 'notif-90'});

      final captured = verify(
        () =>
            dio.post<void>(captureAny(), options: captureAny(named: 'options')),
      ).captured;

      expect(captured.first, '/notifications/notif-90/ack');
      expect((captured[1] as Options).headers?['Authorization'], 'Bearer jwt');
    });

    test('n’accuse pas une notification non critique', () async {
      await run({'type': 'BID_CREATED', 'notificationId': 'notif-91'});
      verifyNever(() => dio.post<void>(any(), options: any(named: 'options')));
    });

    test('ne fait rien sans notificationId', () async {
      await run({'type': 'DISPUTE_OPENED'});
      verifyNever(() => dio.post<void>(any(), options: any(named: 'options')));
    });

    test('ne fait rien sans session Firebase', () async {
      await run({
        'type': 'DELIVERY_CONFIRMED',
        'notificationId': 'notif-92',
      }, idToken: null);
      verifyNever(() => dio.post<void>(any(), options: any(named: 'options')));
    });

    test('avale les erreurs réseau — le SMS reste le filet', () async {
      when(
        () => dio.post<void>(any(), options: any(named: 'options')),
      ).thenThrow(Exception('hors ligne'));

      await expectLater(
        run({'type': 'DISPUTE_OPENED', 'notificationId': 'notif-93'}),
        completes,
      );
    });
  });
}
