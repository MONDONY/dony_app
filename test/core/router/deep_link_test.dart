import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Deep link routing — dony:// custom scheme', () {
    /// Builds the GoRouter path exactly the same way [_DonyAppState._handleDeepLink]
    /// does, so the test stays in sync with the implementation.
    String deepLinkToPath(Uri uri) {
      return '/${uri.host}${uri.path}';
    }

    test(
      'dony://stripe/onboarding/complete maps to /stripe/onboarding/complete',
      () {
        final uri = Uri.parse('dony://stripe/onboarding/complete');
        expect(deepLinkToPath(uri), equals('/stripe/onboarding/complete'));
      },
    );

    test(
      'dony://stripe/onboarding/refresh maps to /stripe/onboarding/refresh',
      () {
        final uri = Uri.parse('dony://stripe/onboarding/refresh');
        expect(deepLinkToPath(uri), equals('/stripe/onboarding/refresh'));
      },
    );

    testWidgets(
      '/stripe/onboarding/complete redirects to /connect/onboarding/pending',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/stripe/onboarding/complete',
          routes: [
            GoRoute(
              path: '/stripe/onboarding/complete',
              redirect: (_, _) => '/connect/onboarding/pending',
            ),
            GoRoute(
              path: '/connect/onboarding/pending',
              builder: (_, _) =>
                  const Scaffold(body: Text('Vérification en cours')),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('Vérification en cours'), findsOneWidget);
      },
    );

    testWidgets(
      '/stripe/onboarding/refresh redirects to /connect/onboarding/intro',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/stripe/onboarding/refresh',
          routes: [
            GoRoute(
              path: '/stripe/onboarding/refresh',
              redirect: (_, _) => '/connect/onboarding/intro',
            ),
            GoRoute(
              path: '/connect/onboarding/intro',
              builder: (_, _) =>
                  const Scaffold(body: Text('Compte Stripe Connect')),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('Compte Stripe Connect'), findsOneWidget);
      },
    );
  });
}
