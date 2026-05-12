import 'package:dony/features/profile/presentation/screens/faq_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _wrap() => MaterialApp.router(
      routerConfig: GoRouter(
        routes: [GoRoute(path: '/', builder: (_, __) => const FaqScreen())],
      ),
    );

void main() {
  testWidgets('renders title and all section headers', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('FAQ & aide'), findsOneWidget);
    expect(find.text('Compte & KYC'), findsOneWidget);
    expect(find.text('Annonces & demandes'), findsOneWidget);
    expect(find.text('Paiements & remboursements'), findsOneWidget);
    expect(find.text('Suivi & livraison'), findsOneWidget);
    expect(find.text('Sécurité & données'), findsOneWidget);
  });

  testWidgets('first section questions are visible as collapsed items', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('Pourquoi la vérification KYC est-elle obligatoire ?'),
      findsOneWidget,
    );
  });

  testWidgets('tapping on a question expands its answer', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    final question = find.text('Pourquoi la vérification KYC est-elle obligatoire ?');
    expect(question, findsOneWidget);

    await tester.tap(question);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.textContaining('lutter contre la fraude'),
      findsOneWidget,
    );
  });

  testWidgets('subtitle is rendered', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('Toutes les réponses aux questions fréquentes.'),
      findsOneWidget,
    );
  });
}
