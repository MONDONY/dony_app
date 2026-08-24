import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  _platformDeepLinkConfig();

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

/// Le routage des liens profonds appartient à `app_links`, jamais au routeur
/// natif de Flutter.
///
/// Ce groupe teste la **configuration de plateforme** et non du code Dart :
/// c'est le seul niveau où le défaut était visible. Quand Flutter route
/// lui-même, il passe l'URI brute de l'intent — schéma compris — à GoRouter,
/// qui répond `GoException: no routes for location: dony://stripe/onboarding/
/// refresh` et affiche « Page Not Found ». Le retour depuis l'onboarding
/// Stripe tombait sur cette impasse, à froid comme à chaud.
///
/// Les tests Dart au-dessus ne pouvaient pas l'attraper : ils vérifient la
/// construction du chemin, qui était correcte — elle n'était simplement jamais
/// atteinte.
void _platformDeepLinkConfig() {
  group('configuration de plateforme des liens profonds', () {
    test('Android laisse app_links router : flutter_deeplinking_enabled '
        'explicitement à false', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

      expect(
        manifest,
        contains(
          '<meta-data android:name="flutter_deeplinking_enabled" '
          'android:value="false" />',
        ),
        reason:
            'Sans ce drapeau, Flutter passe dony://… brut à GoRouter et le '
            'retour depuis Stripe affiche « Page Not Found ». Le drapeau '
            'court-circuite aussi la liste blanche de app.dart.',
      );
    });

    test('les deux retours Stripe restent déclarés dans le manifeste', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      // Sans ces filtres, Android n'ouvre plus l'app du tout au retour de
      // Stripe : le drapeau ci-dessus ne sert alors à rien.
      for (final path in const [
        '/onboarding/complete',
        '/onboarding/refresh',
      ]) {
        expect(
          manifest,
          contains('android:pathPrefix="$path"'),
          reason: 'retour Stripe $path non déclaré',
        );
      }
    });
  });
}
