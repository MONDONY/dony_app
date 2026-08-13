import 'package:dony/features/notifications/notification_route_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bidId = 'b1b2c3d4-e5f6-7890-abcd-ef1234567890';
  const announcementId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
  const threadId = 'c1b2c3d4-e5f6-7890-abcd-ef1234567890';
  const requestId = 'd1b2c3d4-e5f6-7890-abcd-ef1234567890';
  const packageRequestId = 'e1b2c3d4-e5f6-7890-abcd-ef1234567890';
  const conversationId = 'f1b2c3d4-e5f6-7890-abcd-ef1234567890';
  const cancellationId = '123e4567-e89b-12d3-a456-426614174000';

  group('resolveNotificationRoute — types déjà routés côté bid', () {
    for (final type in [
      'PARCEL_REFUSED',
      'BID_EXPIRED',
      'CONFIRMATION_CODE_READY',
      'DELIVERY_NOSHOW_REPORTED',
      'MM_PAYMENT_PENDING',
    ]) {
      test('$type routes to bid detail', () {
        expect(
          resolveNotificationRoute(type, {'bidId': bidId}),
          '/bids/$bidId',
        );
      });

      test('$type without bidId returns null', () {
        expect(resolveNotificationRoute(type, {}), isNull);
      });
    }
  });

  group('resolveNotificationRoute — négociation', () {
    test('negotiation (relance/annulation) routes to thread page', () {
      expect(
        resolveNotificationRoute('negotiation', {'threadId': threadId}),
        '/negotiations/$threadId',
      );
    });

    test('negotiation_expired routes to thread page', () {
      expect(
        resolveNotificationRoute('negotiation_expired', {'threadId': threadId}),
        '/negotiations/$threadId',
      );
    });

    test('request_expired routes to the sender package request', () {
      expect(
        resolveNotificationRoute('request_expired', {
          'packageRequestId': packageRequestId,
        }),
        '/package-requests/$packageRequestId',
      );
    });

    test('request_expired without packageRequestId returns null', () {
      expect(resolveNotificationRoute('request_expired', {}), isNull);
    });
  });

  group('resolveNotificationRoute — TRAVELER_INVITE', () {
    test('routes to the public package request screen', () {
      expect(
        resolveNotificationRoute('TRAVELER_INVITE', {
          'announcementId': announcementId,
          'requestId': requestId,
        }),
        '/package-requests/$requestId/public',
      );
    });

    test('without valid requestId returns null', () {
      expect(
        resolveNotificationRoute('TRAVELER_INVITE', {
          'announcementId': announcementId,
        }),
        isNull,
      );
    });
  });

  group('resolveNotificationRoute — TRIP_IN_PROGRESS', () {
    test('routes to the traveler\'s own trip detail', () {
      expect(
        resolveNotificationRoute('TRIP_IN_PROGRESS', {
          'announcementId': announcementId,
        }),
        '/announcements/$announcementId/trip',
      );
    });

    test('without announcementId returns null', () {
      expect(resolveNotificationRoute('TRIP_IN_PROGRESS', {}), isNull);
    });
  });

  group('resolveNotificationRoute — NEW_MESSAGE', () {
    test(
      'with a valid conversationId deep-links to the exact conversation',
      () {
        expect(
          resolveNotificationRoute('NEW_MESSAGE', {
            'conversationId': conversationId,
          }),
          '/conversations/$conversationId',
        );
      },
    );

    test('without conversationId falls back to the conversation list', () {
      expect(resolveNotificationRoute('NEW_MESSAGE', {}), '/messages');
    });

    test(
      'with a non-UUID conversationId falls back to the conversation list',
      () {
        expect(
          resolveNotificationRoute('NEW_MESSAGE', {
            'conversationId': '../../evil',
          }),
          '/messages',
        );
      },
    );
  });

  group('resolveNotificationRoute — TRIP_CANCELLED', () {
    test('with a valid cancellationId routes to rematch screen', () {
      expect(
        resolveNotificationRoute('TRIP_CANCELLED', {
          'cancellationId': cancellationId,
        }),
        '/cancellations/$cancellationId/rematch',
      );
    });

    test('with only a bidId routes to bid detail', () {
      expect(
        resolveNotificationRoute('TRIP_CANCELLED', {'bidId': bidId}),
        '/bids/$bidId',
      );
    });

    test('with no id at all falls back to shipments history', () {
      expect(
        resolveNotificationRoute('TRIP_CANCELLED', {}),
        '/profile/shipments/history',
      );
    });
  });

  group('resolveNotificationRoute — sans ressource dédiée', () {
    test('ACCOUNT_SUSPENDED routes to the suspended-account screen', () {
      expect(
        resolveNotificationRoute('ACCOUNT_SUSPENDED', {}),
        '/account/disabled',
      );
    });

    test('CARD_EXPIRING routes to the commission card management screen', () {
      expect(
        resolveNotificationRoute('CARD_EXPIRING', {}),
        '/payments/commission-method',
      );
    });

    test('PROMO has no known target and returns null', () {
      expect(resolveNotificationRoute('PROMO', {}), isNull);
    });

    test('unknown type returns null', () {
      expect(resolveNotificationRoute('SOMETHING_NEW', {}), isNull);
    });

    test('null type returns null', () {
      expect(resolveNotificationRoute(null, {}), isNull);
    });
  });

  group('isShellTabRoute', () {
    test('shell tabs use go()', () {
      for (final tab in [
        '/home',
        '/announcements',
        '/tracking',
        '/messages',
        '/profile',
      ]) {
        expect(isShellTabRoute(tab), isTrue, reason: tab);
      }
    });

    test('detail routes use push()', () {
      for (final route in [
        '/bids/$bidId',
        '/negotiations/$threadId',
        '/conversations/$conversationId',
        '/package-requests/$requestId/public',
        '/cancellations/$cancellationId/rematch',
      ]) {
        expect(isShellTabRoute(route), isFalse, reason: route);
      }
    });
  });
}
