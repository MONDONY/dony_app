import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/settings/presentation/screens/legal_web_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../../helpers/fake_web_view_platform.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    WebViewPlatform.instance = FakeWebViewPlatform();
  });

  Widget wrap({
    String title = 'CGU',
    String url = 'https://dony.app/legal/terms',
  }) {
    return MaterialApp(
      home: LegalWebViewScreen(title: title, url: url),
    );
  }

  group('LegalWebViewScreen', () {
    testWidgets('affiche le titre fourni dans l\'AppBar', (tester) async {
      await tester.pumpWidget(wrap());
      expect(find.text('CGU'), findsOneWidget);
    });

    testWidgets('affiche le titre "Politique de confidentialité"', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(title: 'Politique de confidentialité'));
      expect(find.text('Politique de confidentialité'), findsOneWidget);
    });

    testWidgets('affiche l\'icône d\'ouverture externe dans l\'AppBar', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pump(); // une frame pour construire l'appbar
      expect(
        find.byWidgetPredicate(
          (w) => w is DonyIcon && w.name == 'external-link',
        ),
        findsOneWidget,
      );
    });

    // Même garde que sur la WebView du KYC : l'edge-to-edge imposé par
    // Android 15 fait passer le bas de la page sous la barre de navigation.
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

      expect(protections.any((zone) => zone.bottom), isTrue);
    });

    testWidgets('dispose sans erreur', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();
      // Naviguer hors du widget pour déclencher dispose()
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pumpAndSettle();
      // Aucune exception n'est levée
    });
  });
}
