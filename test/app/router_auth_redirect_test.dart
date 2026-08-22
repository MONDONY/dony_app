import 'package:dony/app/router.dart';
import 'package:flutter_test/flutter_test.dart';

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
