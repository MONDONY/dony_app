import 'dart:async';

import 'package:dony/app/system_back_dispatcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('backFallbackFor', () {
    test("ferme l'application depuis l'accueil", () {
      expect(backFallbackFor('/home'), isNull);
    });

    test(
      "ferme l'application depuis les écrans-porte (verrou PIN compris)",
      () {
        for (final gate in [
          '/auth/local',
          '/auth/method',
          '/onboarding',
          '/force-update',
        ]) {
          expect(backFallbackFor(gate), isNull, reason: gate);
        }
      },
    );

    test("ramène les onglets et écrans de détail à l'accueil", () {
      for (final location in [
        '/announcements',
        '/tracking',
        '/messages',
        '/profile',
        '/bids/b1',
        '/payments/wallet',
        '/kyc/verify',
      ]) {
        expect(backFallbackFor(location), '/home', reason: location);
      }
    });

    test('ramène une négociation à la liste des négociations', () {
      expect(backFallbackFor('/negotiations/t1'), '/negotiations');
    });

    test('ramène un sous-écran des réglages aux réglages', () {
      expect(backFallbackFor('/settings/privacy'), '/settings');
    });
  });

  group('SystemBackDispatcher', () {
    late GoRouter router;

    Widget page(String name, {bool canPop = true}) => PopScope(
      canPop: canPop,
      child: Scaffold(body: Text(name)),
    );

    Future<void> pumpApp(WidgetTester tester, String initial) async {
      router = GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(path: '/home', builder: (_, _) => page('home')),
          GoRoute(path: '/announcements', builder: (_, _) => page('tab')),
          GoRoute(path: '/detail', builder: (_, _) => page('detail')),
          GoRoute(
            path: '/locked',
            builder: (_, _) => page('locked', canPop: false),
          ),
          GoRoute(path: '/auth/local', builder: (_, _) => page('pin')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerDelegate: router.routerDelegate,
          routeInformationParser: router.routeInformationParser,
          routeInformationProvider: router.routeInformationProvider,
          backButtonDispatcher: SystemBackDispatcher.forRouter(router),
        ),
      );
      await tester.pumpAndSettle();
    }

    String location() => router.routerDelegate.currentConfiguration.uri.path;

    // Régression : un onglet ou un écran atteint par `go()` est seul dans la
    // pile. Le bouton de l'écran ramenait à l'accueil, le retour du
    // téléphone fermait l'application.
    testWidgets("seul dans la pile : le retour système ramène à l'accueil", (
      tester,
    ) async {
      await pumpApp(tester, '/announcements');

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(location(), '/home');
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('page empilée : le retour système dépile normalement', (
      tester,
    ) async {
      await pumpApp(tester, '/announcements');
      unawaited(router.push('/detail'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(location(), '/announcements');
    });

    testWidgets('un PopScope qui bloque le retour reste prioritaire', (
      tester,
    ) async {
      await pumpApp(tester, '/locked');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(location(), '/locked');
    });

    testWidgets("n'ouvre jamais l'accueil depuis le verrou PIN", (
      tester,
    ) async {
      await pumpApp(tester, '/auth/local');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(location(), '/auth/local');
    });
  });
}
