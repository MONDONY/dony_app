import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockNotificationRepository extends Mock implements NotificationRepository {}

void main() {
  late MockApiClient apiClient;
  late MockNotificationRepository repository;
  late NotificationService service;

  setUp(() {
    apiClient = MockApiClient();
    repository = MockNotificationRepository();
    service = NotificationService(apiClient, repository);
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

    test('TRIP_CANCELLED returns null', () {
      expect(service.testRouteForMessage({'type': 'TRIP_CANCELLED'}), isNull);
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
  });
}
