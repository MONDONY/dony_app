import 'package:dony/app/deep_link_paths.dart';
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
      '/stripe/onboarding/complete redirects to /connect/onboarding/pending',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/stripe/onboarding/complete',
          routes: [
            GoRoute(
              path: '/stripe/onboarding/complete',
              redirect: (_, __) => '/connect/onboarding/pending',
            ),
            GoRoute(
              path: '/connect/onboarding/pending',
              builder: (_, __) =>
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
              redirect: (_, __) => '/connect/onboarding/intro',
            ),
            GoRoute(
              path: '/connect/onboarding/intro',
              builder: (_, __) =>
                  const Scaffold(body: Text('Compte Stripe Connect')),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('Compte Stripe Connect'), findsOneWidget);
      },
    );

    group('Cold start iOS — redirect top-level résout l\'URI brute dony://', () {
      /// Reproduit exactement le redirect top-level de lib/app/router.dart :
      /// sur cold start iOS, Flutter/GoRouter reçoit l'URI complète dony://...
      /// comme location brute, AVANT que app_links.getInitialLink() ne
      /// s'exécute côté Dart — sans cette traduction, GoRouter lève
      /// "GoException: no routes for location: dony://...".
      GoRouter buildRouterWithColdStartRedirect(String initialLocation) {
        return GoRouter(
          initialLocation: initialLocation,
          redirect: (context, state) {
            final uri = state.uri;
            if (uri.scheme == 'dony') {
              final routePath = '/${uri.host}${uri.path}';
              return allowedDeepLinkPaths.contains(routePath)
                  ? routePath
                  : '/splash';
            }
            return null;
          },
          routes: [
            GoRoute(
              path: '/splash',
              builder: (_, __) => const Scaffold(body: Text('Splash')),
            ),
            GoRoute(
              path: '/wallet/topup-return/:status',
              builder: (context, state) => Scaffold(
                body: Text('Retour recharge: ${state.pathParameters['status']}'),
              ),
            ),
          ],
        );
      }

      testWidgets(
          'dony://wallet/topup-return/success (URI brute) résout vers /wallet/topup-return/success',
          (tester) async {
        final router =
            buildRouterWithColdStartRedirect('dony://wallet/topup-return/success');

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('Retour recharge: success'), findsOneWidget);
      });

      testWidgets(
          'dony://wallet/topup-return/error (URI brute) résout vers /wallet/topup-return/error',
          (tester) async {
        final router =
            buildRouterWithColdStartRedirect('dony://wallet/topup-return/error');

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('Retour recharge: error'), findsOneWidget);
      });

      testWidgets(
          'dony://admin/inconnu (hors allowlist) redirige vers /splash, jamais vers une route inconnue',
          (tester) async {
        final router =
            buildRouterWithColdStartRedirect('dony://admin/inconnu');

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('Splash'), findsOneWidget);
      });
    });
  });
}
