import 'package:dony/app/router.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _StubSessionProbe implements FirebaseSessionProbe {
  const _StubSessionProbe({required this.hasRealSession});
  @override
  final bool hasRealSession;
  @override
  bool get hasSession => true;
  @override
  bool get isAnonymous => !hasRealSession;
}

/// Le `redirect` racine du GoRouter est le seul rempart contre la navigation
/// directe et les liens profonds vers une route protégée. Ces tests portent sur
/// la fonction pure qu'il applique, pour la vérifier sans monter Firebase ni
/// l'application entière.
void main() {
  String? redirectFor(
    String location, {
    required bool hasRealSession,
  }) => resolveAuthRedirect(
    matchedLocation: location,
    path: location,
    hasRealSession: hasRealSession,
  );

  group('visiteur (session anonyme ou aucune session)', () {
    // Ces routes n'ont pas de garde propre : elles ne comptent que sur ce
    // redirect. Sans lui, un visiteur y arriverait et n'y récolterait que des
    // échecs réseau bruts.
    const protectedRoutes = [
      '/payments/pay',
      '/payments/wallet',
      '/payments/wallet/topup/amount',
      '/payment/confirm',
      '/kyc/verify',
      '/kyc/status',
      '/profile/edit',
      '/trips/create',
    ];

    for (final route in protectedRoutes) {
      test('$route est renvoyé vers /auth/method', () {
        expect(redirectFor(route, hasRealSession: false), '/auth/method');
      });
    }

    const publicRoutes = [
      '/onboarding',
      '/auth/method',
      '/auth/phone',
      '/auth/otp',
      '/auth/local',
      '/home',
      '/recherche/composer',
      '/package-requests/search',
    ];

    for (final route in publicRoutes) {
      test('$route reste accessible', () {
        expect(redirectFor(route, hasRealSession: false), isNull);
      });
    }

    test('le détail public d\'une demande reste accessible', () {
      expect(
        redirectFor(
          '/package-requests/abc-123/public',
          hasRealSession: false,
        ),
        isNull,
      );
    });

    test('le détail privé d\'une demande reste bloqué', () {
      expect(
        redirectFor('/package-requests/abc-123', hasRealSession: false),
        '/auth/method',
      );
    });
  });

  // La fonction pure ci-dessus peut être juste et le `redirect` réel câblé à
  // l'envers : un booléen inversé au moment du branchement passerait au vert
  // dans tous les cas précédents. Ces tests-ci exercent le `redirect` que
  // GoRouter exécute vraiment, avec le probe réellement lu depuis getIt.
  group('câblage réel du redirect', () {
    tearDown(getIt.reset);

    Future<String?> redirectVia(
      WidgetTester tester,
      String location, {
      required bool hasRealSession,
    }) async {
      getIt.registerSingleton<FirebaseSessionProbe>(
        _StubSessionProbe(hasRealSession: hasRealSession),
      );

      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final state = GoRouterState(
        appRouter.configuration,
        uri: Uri.parse(location),
        matchedLocation: location,
        fullPath: location,
        pathParameters: const {},
        pageKey: ValueKey(location),
      );
      return appRouter.configuration.topRedirect(ctx, state);
    }

    testWidgets('un invité visant le paiement est renvoyé vers /auth/method', (
      tester,
    ) async {
      expect(
        await redirectVia(tester, '/payments/pay', hasRealSession: false),
        '/auth/method',
      );
    });

    testWidgets('un invité visant le KYC est renvoyé vers /auth/method', (
      tester,
    ) async {
      expect(
        await redirectVia(tester, '/kyc/verify', hasRealSession: false),
        '/auth/method',
      );
    });

    testWidgets('un invité garde l\'accueil', (tester) async {
      expect(
        await redirectVia(tester, '/home', hasRealSession: false),
        isNull,
      );
    });

    testWidgets('un utilisateur réel atteint le paiement', (tester) async {
      expect(
        await redirectVia(tester, '/payments/pay', hasRealSession: true),
        isNull,
      );
    });

    testWidgets('un utilisateur réel atteint le portefeuille', (tester) async {
      expect(
        await redirectVia(tester, '/payments/wallet', hasRealSession: true),
        isNull,
      );
    });
  });

  group('utilisateur réel', () {
    const routes = [
      '/payments/pay',
      '/payments/wallet',
      '/payment/confirm',
      '/kyc/verify',
      '/profile/edit',
      '/trips/create',
      '/home',
      '/package-requests/abc-123',
    ];

    for (final route in routes) {
      test('$route n\'est jamais détourné : $route', () {
        expect(redirectFor(route, hasRealSession: true), isNull);
      });
    }
  });
}
