import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      );

  group('DonyEmptyState', () {
    testWidgets('loading type shows CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(wrap(
        const DonyEmptyState(
          title: 'Chargement',
          type: DonyEmptyStateType.loading,
        ),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Chargement'), findsNothing);
    });

    testWidgets('empty type shows icon + title', (tester) async {
      await tester.pumpWidget(wrap(
        const DonyEmptyState(title: 'Aucun colis'),
      ));
      expect(find.text('Aucun colis'), findsOneWidget);
      expect(find.byType(DonyIconContainer), findsOneWidget);
    });

    testWidgets('empty type shows description when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const DonyEmptyState(
          title: 'Aucun colis',
          description: 'Ajoutez votre premier colis.',
        ),
      ));
      expect(find.text('Ajoutez votre premier colis.'), findsOneWidget);
    });

    testWidgets('empty type shows CTA button when actionLabel provided', (tester) async {
      var pressed = false;
      await tester.pumpWidget(wrap(
        DonyEmptyState(
          title: 'Aucun colis',
          actionLabel: 'Envoyer un colis',
          onAction: () => pressed = true,
        ),
      ));
      expect(find.text('Envoyer un colis'), findsOneWidget);
      await tester.tap(find.text('Envoyer un colis'));
      expect(pressed, isTrue);
    });

    testWidgets('error type shows error icon container', (tester) async {
      await tester.pumpWidget(wrap(
        const DonyEmptyState(
          title: 'Erreur réseau',
          type: DonyEmptyStateType.error,
        ),
      ));
      expect(find.text('Erreur réseau'), findsOneWidget);
      expect(find.byType(DonyIconContainer), findsOneWidget);
    });

    testWidgets('error type with CTA uses primary button variant', (tester) async {
      await tester.pumpWidget(wrap(
        DonyEmptyState(
          title: 'Erreur',
          type: DonyEmptyStateType.error,
          actionLabel: 'Réessayer',
          onAction: () {},
        ),
      ));
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('custom icon overrides default', (tester) async {
      await tester.pumpWidget(wrap(
        const DonyEmptyState(
          title: 'Inbox vide',
          icon: Icons.mail_outline,
        ),
      ));
      expect(find.byIcon(Icons.mail_outline), findsOneWidget);
    });

    testWidgets('custom padding is respected', (tester) async {
      await tester.pumpWidget(wrap(
        const DonyEmptyState(
          title: 'Vide',
          padding: EdgeInsets.all(8),
        ),
      ));
      expect(find.text('Vide'), findsOneWidget);
    });

    testWidgets('no CTA shown when actionLabel is null', (tester) async {
      await tester.pumpWidget(wrap(
        const DonyEmptyState(title: 'Vide'),
      ));
      expect(find.byType(DonyButton), findsNothing);
    });
  });
}
