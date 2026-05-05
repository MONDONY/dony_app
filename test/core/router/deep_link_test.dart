import 'package:dony/app/router.dart';
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

    test('dony://stripe/onboarding/complete maps to /stripe/onboarding/complete', () {
      final uri = Uri.parse('dony://stripe/onboarding/complete');
      expect(deepLinkToPath(uri), equals('/stripe/onboarding/complete'));
    });

    test('dony://stripe/onboarding/refresh maps to /stripe/onboarding/refresh', () {
      final uri = Uri.parse('dony://stripe/onboarding/refresh');
      expect(deepLinkToPath(uri), equals('/stripe/onboarding/refresh'));
    });

    testWidgets(
      '/stripe/onboarding/complete renders the Stripe onboarding complete screen',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/stripe/onboarding/complete',
          routes: appRouter.configuration.routes,
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router),
        );
        await tester.pumpAndSettle();

        expect(find.text('Onboarding Stripe complet'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      '/stripe/onboarding/refresh renders the Stripe onboarding refresh screen',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/stripe/onboarding/refresh',
          routes: appRouter.configuration.routes,
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router),
        );
        await tester.pumpAndSettle();

        expect(find.text('Actualisation onboarding Stripe'), findsAtLeastNWidgets(1));
      },
    );
  });
}
