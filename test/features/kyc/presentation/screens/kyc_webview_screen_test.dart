import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../helpers/fake_web_view_platform.dart';
import '../../../../helpers/l10n_test_helpers.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late _MockAnalyticsService analytics;

  setUpAll(() {
    WebViewPlatform.instance = FakeWebViewPlatform();
  });

  setUp(() {
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logScreen(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  Widget wrap({String url = 'https://verify.stripe.com/start'}) => MaterialApp(
    home: KycWebViewScreen(stripeUrl: url, analytics: analytics),
  );

  group('KycWebViewScreen', () {
    // L'écran de statut et la WebView partagent la route `/kyc/verify` : sans
    // ce second `$screen`, PostHog comptait toute sortie du parcours Didit
    // comme une sortie de l'écran de statut.
    testWidgets('envoie un nom d\'écran propre à la WebView Didit', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(url: 'https://verify.didit.me/session/x'));

      verify(
        () => analytics.logScreen(
          AnalyticsEvents.kycProviderWebviewScreen,
          properties: {'provider': 'didit'},
        ),
      ).called(1);
    });

    testWidgets('indique Stripe quand la session vient de Stripe', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());

      verify(
        () => analytics.logScreen(
          AnalyticsEvents.kycProviderWebviewScreen,
          properties: {'provider': 'stripe'},
        ),
      ).called(1);
    });

    testWidgets('affiche le titre de vérification', (tester) async {
      await tester.pumpWidget(wrap());
      expect(find.text('Vérification d\'identité'), findsOneWidget);
    });

    testWidgets('affiche le titre en anglais', (tester) async {
      useEnglish();
      await tester.pumpWidget(wrap());
      expect(find.text('Identity verification'), findsOneWidget);
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

    // Régression : l'écran n'a pas de bouton retour, seulement la croix.
    // Ouvert par `go()`, il est seul dans la pile : le retour du téléphone
    // fermait l'application en pleine vérification d'identité.
    testWidgets('intercepte le retour système au lieu de fermer l\'app', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());

      final scope = tester.widget<PopScope>(
        find.ancestor(
          of: find.byType(WebViewWidget),
          matching: find.byWidgetPredicate((w) => w is PopScope),
        ),
      );
      expect(scope.canPop, isFalse);
      expect(scope.onPopInvokedWithResult, isNotNull);
    });
  });
}
