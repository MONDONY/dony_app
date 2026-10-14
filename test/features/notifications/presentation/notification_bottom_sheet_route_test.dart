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
    const bidId = 'b1b2c3d4-e5f6-7890-abcd-ef1234567890';

    test('REFERRAL_REWARD_AVAILABLE : le deeplink ouvre Parrainage', () {
      final n = NotificationModel(
        id: 'n1',
        type: 'REFERRAL_REWARD_AVAILABLE',
        title: 't',
        body: 'b',
        data: const {'invitationId': annId, 'route': '/profile/referral'},
        read: false,
        createdAt: DateTime(2026),
        deeplink: 'yadony://profile/referral',
      );
      expect(routeForNotification(n), '/profile/referral');
      // Sans deeplink, le resolver partagé avec la push donne la même cible.
      expect(
        routeForNotification(_notif('REFERRAL_REWARD_AVAILABLE')),
        '/profile/referral',
      );
    });

    test(
      'SUPPORT_MESSAGE du centre de notifications ouvre la conversation',
      () {
        expect(
          routeForNotification(
            _notif('SUPPORT_MESSAGE', data: {'ticketId': annId}),
          ),
          '/support/tickets/$annId',
        );
      },
    );

    test('SUPPORT_MESSAGE : le deeplink serveur ouvre la conversation', () {
      final n = NotificationModel(
        id: 'n1',
        type: 'SUPPORT_MESSAGE',
        title: 't',
        body: 'b',
        data: const {'type': 'SUPPORT_MESSAGE', 'ticketId': annId},
        read: false,
        createdAt: DateTime(2026),
        category: 'colis',
        deeplink: 'yadony://support/tickets/$annId',
      );
      expect(routeForNotification(n), '/support/tickets/$annId');
    });

    test('SUPPORT_MESSAGE : le deeplink de repli ouvre la liste', () {
      final n = NotificationModel(
        id: 'n1',
        type: 'SUPPORT_MESSAGE',
        title: 't',
        body: 'b',
        data: const {},
        read: false,
        createdAt: DateTime(2026),
        deeplink: 'yadony://support',
      );
      expect(routeForNotification(n), '/support');
    });

    test('SUPPORT_MESSAGE sans ticketId ouvre la liste du support', () {
      expect(routeForNotification(_notif('SUPPORT_MESSAGE')), '/support');
    });

    test('CORRIDOR_ALERT routes to the matching trip detail', () {
      expect(
        routeForNotification(
          _notif('CORRIDOR_ALERT', data: {'announcementId': annId}),
        ),
        '/traveler/$annId',
      );
    });

    test('CORRIDOR_ALERT without announcementId falls back to the detail', () {
      expect(
        routeForNotification(_notif('CORRIDOR_ALERT')),
        '/notifications/n1',
      );
    });

    test('PACKAGE_MATCH routes to the matching package request detail', () {
      expect(
        routeForNotification(
          _notif('PACKAGE_MATCH', data: {'requestId': annId}),
        ),
        '/package-requests/$annId/public',
      );
    });

    test('PACKAGE_MATCH without requestId falls back to the detail', () {
      expect(
        routeForNotification(_notif('PACKAGE_MATCH')),
        '/notifications/n1',
      );
    });

    test('BID_CREATED ouvre la demande dans « Demandes reçues »', () {
      expect(
        routeForNotification(
          _notif(
            'BID_CREATED',
            data: {'bidId': bidId, 'announcementId': annId},
          ),
        ),
        '/demandes?bid=$bidId',
      );
    });

    test('BID_CREATED sans bidId retombe sur la page de l\'annonce', () {
      expect(
        routeForNotification(
          _notif('BID_CREATED', data: {'announcementId': annId}),
        ),
        '/announcements/$annId/bids',
      );
    });

    test('BID_CREATED : le deeplink serveur garde sa demande', () {
      final n = NotificationModel(
        id: 'n1',
        type: 'BID_CREATED',
        title: 't',
        body: 'b',
        data: {'bidId': bidId, 'announcementId': annId},
        read: false,
        createdAt: DateTime(2026),
        deeplink: 'yadony://demandes?bid=$bidId',
      );
      expect(routeForNotification(n), '/demandes?bid=$bidId');
    });

    test('BID_ACCEPTED routes to bid detail', () {
      expect(
        routeForNotification(_notif('BID_ACCEPTED', data: {'bidId': bidId})),
        '/bids/$bidId',
      );
    });

    test('BID_ACCEPTED with non-UUID bidId falls back to the detail', () {
      expect(
        routeForNotification(
          _notif('BID_ACCEPTED', data: {'bidId': '../../evil'}),
        ),
        '/notifications/n1',
      );
    });

    test('BID_REJECTED without cancellationId routes to bid detail', () {
      expect(
        routeForNotification(_notif('BID_REJECTED', data: {'bidId': bidId})),
        '/bids/$bidId',
      );
    });

    test('BID_REJECTED with valid cancellationId routes to rematch screen', () {
      expect(
        routeForNotification(
          _notif(
            'BID_REJECTED',
            data: {'cancellationId': annId, 'bidId': bidId},
          ),
        ),
        '/cancellations/$annId/rematch',
      );
    });

    test(
      'BID_REJECTED with non-UUID cancellationId falls back to bid detail',
      () {
        expect(
          routeForNotification(
            _notif(
              'BID_REJECTED',
              data: {'cancellationId': '../../evil', 'bidId': bidId},
            ),
          ),
          '/bids/$bidId',
        );
      },
    );

    test(
      'BID_REJECTED with valid cancellationId and no bidId routes to rematch screen',
      () {
        expect(
          routeForNotification(
            _notif('BID_REJECTED', data: {'cancellationId': annId}),
          ),
          '/cancellations/$annId/rematch',
        );
      },
    );

    test('unknown type falls back to the detail', () {
      expect(routeForNotification(_notif('WHATEVER')), '/notifications/n1');
    });

    test(
      'TRIP_CANCELLED with valid cancellationId routes to rematch screen',
      () {
        expect(
          routeForNotification(
            _notif('TRIP_CANCELLED', data: {'cancellationId': annId}),
          ),
          '/cancellations/$annId/rematch',
        );
      },
    );

    test('TRIP_CANCELLED without any id falls back to shipments history', () {
      expect(
        routeForNotification(_notif('TRIP_CANCELLED')),
        '/profile/shipments/history',
      );
    });

    test(
      'TRIP_CANCELLED with non-UUID cancellationId falls back to shipments history',
      () {
        expect(
          routeForNotification(
            _notif('TRIP_CANCELLED', data: {'cancellationId': 'not-a-uuid'}),
          ),
          '/profile/shipments/history',
        );
      },
    );

    test('TRIP_CANCELLED with bidId only routes to bid detail', () {
      expect(
        routeForNotification(_notif('TRIP_CANCELLED', data: {'bidId': bidId})),
        '/bids/$bidId',
      );
    });
  });

  group('FLIGHT_PRICE_ALERT dans la boîte de notifications', () {
    const alertId = '0a1b2c3d-e5f6-7890-abcd-ef1234567890';

    NotificationModel alert(Map<String, dynamic> data) => NotificationModel(
      id: 'n1',
      type: 'FLIGHT_PRICE_ALERT',
      title: 't',
      body: 'b',
      data: data,
      read: false,
      createdAt: DateTime(2026),
      deeplink: 'yadony://flights/alerts',
    );

    test('avec un alertId valide : les vols trouvés, malgré le deeplink', () {
      expect(
        routeForNotification(
          alert(const {'alertId': alertId, 'matchCount': '3'}),
        ),
        '/flights/alerts/$alertId/offers?source=notification',
      );
    });

    test('sans alertId valide : le deeplink garde la main', () {
      expect(routeForNotification(alert(const {})), '/flights/alerts');
      expect(
        routeForNotification(alert(const {'alertId': '../x'})),
        '/flights/alerts',
      );
    });

    test('un autre type garde la priorité du deeplink', () {
      final n = NotificationModel(
        id: 'n1',
        type: 'CORRIDOR_ALERT',
        title: 't',
        body: 'b',
        data: const {'alertId': alertId},
        read: false,
        createdAt: DateTime(2026),
        deeplink: 'yadony://flights/alerts',
      );
      expect(routeForNotification(n), '/flights/alerts');
    });
  });
}
