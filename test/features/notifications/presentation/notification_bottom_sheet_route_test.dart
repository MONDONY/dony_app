import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/presentation/notification_bottom_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

NotificationModel _notif(String type, {Map<String, dynamic> data = const {}}) {
  return NotificationModel(
    id: 'n1',
    type: type,
    title: 't',
    body: 'b',
    data: data,
    read: false,
    createdAt: DateTime(2026),
  );
}

void main() {
  group('routeForNotification', () {
    const annId = '123e4567-e89b-12d3-a456-426614174000';

    test('CORRIDOR_ALERT routes to the matching trip detail', () {
      expect(
        routeForNotification(
          _notif('CORRIDOR_ALERT', data: {'announcementId': annId}),
        ),
        '/traveler/$annId',
      );
    });

    test('CORRIDOR_ALERT without announcementId returns null', () {
      expect(routeForNotification(_notif('CORRIDOR_ALERT')), isNull);
    });

    test('PACKAGE_MATCH routes to the matching package request detail', () {
      expect(
        routeForNotification(
          _notif('PACKAGE_MATCH', data: {'requestId': annId}),
        ),
        '/package-requests/$annId/public',
      );
    });

    test('PACKAGE_MATCH without requestId returns null', () {
      expect(routeForNotification(_notif('PACKAGE_MATCH')), isNull);
    });

    test('BID_CREATED routes to announcement bids page', () {
      expect(
        routeForNotification(
          _notif('BID_CREATED', data: {'announcementId': annId}),
        ),
        '/announcements/$annId/bids',
      );
    });

    test('BID_ACCEPTED routes to bid detail', () {
      expect(
        routeForNotification(_notif('BID_ACCEPTED', data: {'bidId': 'b1'})),
        '/bids/b1',
      );
    });

    test('BID_REJECTED without cancellationId routes to bid detail', () {
      expect(
        routeForNotification(_notif('BID_REJECTED', data: {'bidId': 'b1'})),
        '/bids/b1',
      );
    });

    test('BID_REJECTED with valid cancellationId routes to rematch screen', () {
      expect(
        routeForNotification(
          _notif('BID_REJECTED', data: {'cancellationId': annId, 'bidId': 'b1'}),
        ),
        '/cancellations/$annId/rematch',
      );
    });

    test('BID_REJECTED with non-UUID cancellationId falls back to bid detail', () {
      expect(
        routeForNotification(
          _notif('BID_REJECTED', data: {'cancellationId': '../../evil', 'bidId': 'b1'}),
        ),
        '/bids/b1',
      );
    });

    test('BID_REJECTED with valid cancellationId and no bidId routes to rematch screen', () {
      expect(
        routeForNotification(_notif('BID_REJECTED', data: {'cancellationId': annId})),
        '/cancellations/$annId/rematch',
      );
    });

    test('unknown type returns null', () {
      expect(routeForNotification(_notif('WHATEVER')), isNull);
    });

    test('TRIP_CANCELLED with valid cancellationId routes to rematch screen', () {
      expect(
        routeForNotification(
          _notif('TRIP_CANCELLED', data: {'cancellationId': annId}),
        ),
        '/cancellations/$annId/rematch',
      );
    });

    test('TRIP_CANCELLED without cancellationId returns null', () {
      expect(routeForNotification(_notif('TRIP_CANCELLED')), isNull);
    });

    test('TRIP_CANCELLED with non-UUID cancellationId returns null', () {
      expect(
        routeForNotification(
          _notif('TRIP_CANCELLED', data: {'cancellationId': 'not-a-uuid'}),
        ),
        isNull,
      );
    });
  });
}
