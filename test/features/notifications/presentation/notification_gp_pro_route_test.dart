import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/presentation/notification_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Recette 7.9 : « Badge GP Pro retiré » ne doit jamais ouvrir l'écran de
/// détail générique. Les lignes ci-dessous reprennent la forme exacte du feed
/// du back (`FeedItemDTO` : type, deeplink `yadony://profile/gp-pro`, data
/// réduit à `{type}` comme l'envoie `GpProNotificationListener`).
void main() {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox()),
      GoRoute(path: '/profile/gp-pro', builder: (_, _) => const SizedBox()),
      GoRoute(path: '/notifications/:id', builder: (_, _) => const SizedBox()),
    ],
  );
  bool exists(String r) => notificationRouteExists(router, r);

  Map<String, dynamic> feedRow(
    String type, {
    String? deeplink = 'yadony://profile/gp-pro',
    int count = 1,
  }) => {
    'id': '11111111-1111-4111-8111-111111111111',
    'type': type,
    'category': 'annonce',
    'title': 'Badge GP Pro retiré',
    'body': 'Votre badge GP Pro a été retiré.',
    'deeplink': deeplink,
    'groupKey': 'notif:11111111-1111-4111-8111-111111111111',
    'data': {'type': type},
    'read': false,
    'createdAt': '2026-11-10T10:00:00',
    'count': count,
    'notificationIds': ['11111111-1111-4111-8111-111111111111'],
  };

  const types = ['GP_PRO_APPROVED', 'GP_PRO_REJECTED', 'GP_PRO_REVOKED'];

  for (final type in types) {
    test('$type : ligne du feed avec deeplink ouvre l\'écran GP Pro', () {
      final n = NotificationModel.fromJson(feedRow(type));
      expect(routeForNotification(n), '/profile/gp-pro');
      expect(openableRouteForNotification(n, exists), '/profile/gp-pro');
    });

    test(
      '$type : ligne sans deeplink (ancienne ligne) : route par le type',
      () {
        final n = NotificationModel.fromJson(feedRow(type, deeplink: null));
        expect(routeForNotification(n), '/profile/gp-pro');
        expect(openableRouteForNotification(n, exists), '/profile/gp-pro');
      },
    );

    test('$type : deeplink illisible : repli sur la route du type', () {
      final n = NotificationModel.fromJson(
        feedRow(type, deeplink: 'yadony://'),
      );
      expect(openableRouteForNotification(n, exists), '/profile/gp-pro');
    });
  }

  test('ligne agrégée sans deeplink : le type porte encore la route', () {
    final n = NotificationModel.fromJson(
      feedRow('GP_PRO_REVOKED', deeplink: null, count: 3),
    );
    expect(openableRouteForNotification(n, exists), '/profile/gp-pro');
  });
}
