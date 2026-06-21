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

    test('unknown type returns null', () {
      expect(routeForNotification(_notif('WHATEVER')), isNull);
    });
  });
}
