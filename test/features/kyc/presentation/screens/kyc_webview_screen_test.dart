import 'package:dony/features/kyc/presentation/screens/kyc_webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../helpers/fake_web_view_platform.dart';

void main() {
  setUpAll(() {
    WebViewPlatform.instance = FakeWebViewPlatform();
  });

  Widget wrap() => const MaterialApp(
    home: KycWebViewScreen(stripeUrl: 'https://verify.stripe.com/start'),
  );

  group('KycWebViewScreen', () {
    testWidgets('affiche le titre de vérification', (tester) async {
      await tester.pumpWidget(wrap());
      expect(find.text('Vérification d\'identité'), findsOneWidget);
    });

    // Régression : la WebView occupait toute la hauteur, barre de navigation
    // comprise. Sur Android 15 l'edge-to-edge est imposé, donc le bouton
    // d'action de la page Stripe, ancré en bas, tombait entièrement sous la
    // barre système : invisible, intouchable, et le parcours d'identité ne
    // pouvait que finir en abandon.
    testWidgets('protège le bas de la WebView de la barre de navigation', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());

      final protections = tester.widgetList<SafeArea>(
        find.ancestor(
          of: find.byType(WebViewWidget),
          matching: find.byType(SafeArea),
        ),
      );

      expect(
        protections.any((zone) => zone.bottom),
        isTrue,
        reason:
            'la WebView doit être protégée en bas, sinon le bouton d\'action '
            'de la page distante passe sous la barre de navigation',
      );
    });
  });
}
