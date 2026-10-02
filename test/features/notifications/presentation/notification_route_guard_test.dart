import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/presentation/notification_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Un deeplink périmé ou inconnu de cette version de l'app ne doit jamais
/// ouvrir la page d'erreur par défaut : la garde le détecte avant de pousser.
void main() {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox()),
      GoRoute(path: '/bids/:id', builder: (_, _) => const SizedBox()),
      GoRoute(
        path: '/notifications/annonces',
        builder: (_, _) => const SizedBox(),
      ),
      GoRoute(path: '/notifications/:id', builder: (_, _) => const SizedBox()),
      GoRoute(path: '/profile/recipients', builder: (_, _) => const SizedBox()),
    ],
  );

  test('une route déclarée est connue', () {
    expect(notificationRouteExists(router, '/bids/b1'), isTrue);
    expect(notificationRouteExists(router, '/notifications/annonces'), isTrue);
    expect(notificationRouteExists(router, '/notifications/a1'), isTrue);
  });

  test('une route absente ou malformée est refusée', () {
    expect(notificationRouteExists(router, '/nulle-part/x'), isFalse);
    expect(notificationRouteExists(router, '/bids'), isFalse);
    expect(notificationRouteExists(router, '::pas une uri::'), isFalse);
  });

  group('openableRouteForNotification (FLUTTER-7W)', () {
    NotificationModel notif(String type, {String? deeplink}) =>
        NotificationModel(
          id: 'n1',
          type: type,
          title: 't',
          body: 'b',
          data: const {},
          read: false,
          createdAt: DateTime(2026),
          deeplink: deeplink,
        );
    bool exists(String r) => notificationRouteExists(router, r);

    test('un deeplink connu est suivi tel quel', () {
      expect(
        openableRouteForNotification(
          notif('BID_ACCEPTED', deeplink: 'yadony://bids/b1'),
          exists,
        ),
        '/bids/b1',
      );
    });

    test('un deeplink inconnu retombe sur la route du type', () {
      expect(
        openableRouteForNotification(
          notif(
            'RECIPIENT_INVITATION_ACCEPTED',
            deeplink: 'yadony://recipients',
          ),
          exists,
        ),
        '/profile/recipients',
      );
    });

    test('sans repli connu, aucune route : le toast s\'affiche', () {
      expect(
        openableRouteForNotification(
          notif('WHATEVER', deeplink: 'yadony://nulle-part'),
          exists,
        ),
        isNull,
      );
    });
  });
}
