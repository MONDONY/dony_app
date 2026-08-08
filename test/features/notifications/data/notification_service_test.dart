import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/services/device_id_service.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockNotificationRepository extends Mock implements NotificationRepository {}
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
      when(() => deviceIdService.getDeviceId())
          .thenAnswer((_) async => 'test-device-id-uuid');
    });

    test('sends fcmToken, deviceId, deviceName and platform to the endpoint', () async {
      when(
        () => mockDio.put(
          '/auth/me/fcm-token',
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/auth/me/fcm-token'),
            statusCode: 200,
          ));

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
    });

    test('swallows errors silently when upload fails', () async {
      when(
        () => mockDio.put(
          '/auth/me/fcm-token',
          data: any(named: 'data'),
        ),
      ).thenThrow(Exception('network error'));

      await expectLater(
        service.testUploadToken('test-fcm-token'),
        completes,
      );
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
  const _annId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
  const _bidId = 'b1b2c3d4-e5f6-7890-abcd-ef1234567890';
  const _threadId = 'c1b2c3d4-e5f6-7890-abcd-ef1234567890';

  group('NotificationService.formatAndroidName', () {
    test('préfixe le fabricant quand le modèle ne commence pas par lui', () {
      expect(
        NotificationService.formatAndroidName('xiaomi', '25028RN03Y'),
        'Xiaomi 25028RN03Y',
      );
    });

    test('ne duplique pas le fabricant quand le modèle commence déjà par lui', () {
      expect(
        NotificationService.formatAndroidName('Samsung', 'Samsung Galaxy S22'),
        'Samsung Galaxy S22',
      );
    });

    test('retourne le modèle seul quand le fabricant est vide', () {
      expect(
        NotificationService.formatAndroidName('', 'Pixel 7'),
        'Pixel 7',
      );
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
        service.testRouteForMessage({'type': 'BID_CREATED', 'announcementId': _annId}),
        '/announcements/$_annId/bids',
      );
    });

    test('BID_ACCEPTED routes to bid detail', () {
      expect(service.testRouteForMessage({'type': 'BID_ACCEPTED', 'bidId': _bidId}), '/bids/$_bidId');
    });

    test('BID_REJECTED routes to bid detail', () {
      expect(service.testRouteForMessage({'type': 'BID_REJECTED', 'bidId': _bidId}), '/bids/$_bidId');
    });

    test('BID_REJECTED with valid cancellationId routes to rematch screen', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      expect(
        service.testRouteForMessage({
          'type': 'BID_REJECTED',
          'bidId': _bidId,
          'cancellationId': uuid,
        }),
        '/cancellations/$uuid/rematch',
      );
    });

    test('BID_REJECTED with non-UUID cancellationId falls back to bid detail', () {
      expect(
        service.testRouteForMessage({
          'type': 'BID_REJECTED',
          'bidId': _bidId,
          'cancellationId': '../../evil',
        }),
        '/bids/$_bidId',
      );
    });

    test('BID_REJECTED with valid cancellationId and no bidId routes to rematch screen', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      expect(
        service.testRouteForMessage({
          'type': 'BID_REJECTED',
          'cancellationId': uuid,
        }),
        '/cancellations/$uuid/rematch',
      );
    });

    test('HANDOVER_DEFINED routes to bid detail', () {
      expect(service.testRouteForMessage({'type': 'HANDOVER_DEFINED', 'bidId': _bidId}), '/bids/$_bidId');
    });

    test('DELIVERY_CONFIRMED routes to bid detail', () {
      expect(service.testRouteForMessage({'type': 'DELIVERY_CONFIRMED', 'bidId': _bidId}), '/bids/$_bidId');
    });

    test('PAYMENT_RELEASED routes to bid detail', () {
      expect(service.testRouteForMessage({'type': 'PAYMENT_RELEASED', 'bidId': _bidId}), '/bids/$_bidId');
    });

    test('DISPUTE_OPENED routes to bid detail', () {
      expect(service.testRouteForMessage({'type': 'DISPUTE_OPENED', 'bidId': _bidId}), '/bids/$_bidId');
    });

    test('TRIP_CANCELLED without any id falls back to shipments history', () {
      expect(
        service.testRouteForMessage({'type': 'TRIP_CANCELLED'}),
        '/profile/shipments/history',
      );
    });

    test('TRIP_CANCELLED with valid cancellationId routes to rematch screen', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      expect(
        service.testRouteForMessage({
          'type': 'TRIP_CANCELLED',
          'cancellationId': uuid,
        }),
        '/cancellations/$uuid/rematch',
      );
    });

    test('TRIP_CANCELLED with non-UUID cancellationId falls back to shipments history', () {
      expect(
        service.testRouteForMessage({
          'type': 'TRIP_CANCELLED',
          'cancellationId': 'not-a-uuid',
        }),
        '/profile/shipments/history',
      );
    });

    test('TRIP_CANCELLED with bidId only routes to bid detail', () {
      expect(
        service.testRouteForMessage({'type': 'TRIP_CANCELLED', 'bidId': _bidId}),
        '/bids/$_bidId',
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
        service.testRouteForMessage({'type': 'negotiation_started', 'threadId': _threadId}),
        '/negotiations/$_threadId',
      );
    });

    test('negotiation_counter routes to thread page', () {
      expect(
        service.testRouteForMessage({'type': 'negotiation_counter', 'threadId': _threadId}),
        '/negotiations/$_threadId',
      );
    });

    test('negotiation_awaiting_trip routes to thread page', () {
      expect(
        service.testRouteForMessage({'type': 'negotiation_awaiting_trip', 'threadId': _threadId}),
        '/negotiations/$_threadId',
      );
    });

    test('negotiation_awaiting_payment routes to thread page', () {
      expect(
        service.testRouteForMessage({'type': 'negotiation_awaiting_payment', 'threadId': _threadId}),
        '/negotiations/$_threadId',
      );
    });

    test('negotiation_started without threadId returns null', () {
      expect(service.testRouteForMessage({'type': 'negotiation_started'}), isNull);
    });

    test('request_accepted routes to thread page', () {
      expect(
        service.testRouteForMessage({'type': 'request_accepted', 'threadId': _threadId}),
        '/negotiations/$_threadId',
      );
    });

    test('TRAVELER_NEW_ANNOUNCEMENT routes to traveler announcement detail', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      expect(
        service.testRouteForMessage({
          'type': 'TRAVELER_NEW_ANNOUNCEMENT',
          'announcementId': uuid,
        }),
        '/traveler/$uuid',
      );
    });

    test('TRAVELER_NEW_ANNOUNCEMENT without valid announcementId returns null', () {
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
    });

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
      expect(
        service.testRouteForMessage({'type': 'CORRIDOR_ALERT'}),
        isNull,
      );
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
}
