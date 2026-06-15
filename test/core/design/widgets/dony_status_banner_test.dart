import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      )),
    );

void main() {
  group('DonyStatusBanner — rendu par type', () {
    testWidgets('info — affiche icône info par défaut', (tester) async {
      await tester.pumpWidget(_wrap(const DonyStatusBanner(
        type: DonyStatusBannerType.info,
        message: 'Test info',
      )));
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      expect(find.text('Test info'), findsOneWidget);
    });

    testWidgets('warning — affiche icône warning par défaut', (tester) async {
      await tester.pumpWidget(_wrap(const DonyStatusBanner(
        type: DonyStatusBannerType.warning,
        message: 'Test warning',
      )));
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('error — affiche icône error par défaut', (tester) async {
      await tester.pumpWidget(_wrap(const DonyStatusBanner(
        type: DonyStatusBannerType.error,
        message: 'Test error',
      )));
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('success — affiche icône check par défaut', (tester) async {
      await tester.pumpWidget(_wrap(const DonyStatusBanner(
        type: DonyStatusBannerType.success,
        message: 'Test success',
      )));
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });
  });

  group('DonyStatusBanner — paramètres optionnels', () {
    testWidgets('icon override remplace l\'icône par défaut', (tester) async {
      await tester.pumpWidget(_wrap(const DonyStatusBanner(
        type: DonyStatusBannerType.info,
        icon: Icons.lock_rounded,
        message: 'Paiement sécurisé',
      )));
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
    });

    testWidgets('title s\'affiche au-dessus du message', (tester) async {
      await tester.pumpWidget(_wrap(const DonyStatusBanner(
        type: DonyStatusBannerType.error,
        title: 'Erreur réseau',
        message: 'Vérifiez votre connexion',
      )));
      expect(find.text('Erreur réseau'), findsOneWidget);
      expect(find.text('Vérifiez votre connexion'), findsOneWidget);
    });

    testWidgets('onDismiss affiche la croix de fermeture', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(_wrap(DonyStatusBanner(
        type: DonyStatusBannerType.info,
        message: 'Dismissable',
        onDismiss: () => dismissed = true,
      )));
      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'), findsOneWidget);
      await tester.tap(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'));
      expect(dismissed, isTrue);
    });

    testWidgets('sans onDismiss — pas de croix', (tester) async {
      await tester.pumpWidget(_wrap(const DonyStatusBanner(
        type: DonyStatusBannerType.info,
        message: 'Non dismissable',
      )));
      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'), findsNothing);
    });

    testWidgets('action widget s\'affiche sous le message', (tester) async {
      await tester.pumpWidget(_wrap(DonyStatusBanner(
        type: DonyStatusBannerType.warning,
        message: 'Attention',
        action: TextButton(onPressed: () {}, child: const Text('Réessayer')),
      )));
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });

  group('DonyStatusBanner — rich text (messageSpan)', () {
    testWidgets('messageSpan rend le rich text', (tester) async {
      await tester.pumpWidget(_wrap(const DonyStatusBanner(
        type: DonyStatusBannerType.info,
        icon: Icons.shield_outlined,
        messageSpan: TextSpan(
          children: [
            TextSpan(text: 'Remboursement jusqu\'à '),
            TextSpan(
              text: '200 €',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: ' garanti.'),
          ],
        ),
      )));
      expect(find.textContaining('200 €'), findsOneWidget);
      expect(find.textContaining('garanti'), findsOneWidget);
    });

    testWidgets('messageSpan — pas d\'icône info (override shield)', (tester) async {
      await tester.pumpWidget(_wrap(const DonyStatusBanner(
        type: DonyStatusBannerType.info,
        icon: Icons.shield_outlined,
        messageSpan: TextSpan(text: 'test'),
      )));
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
    });
  });
}
