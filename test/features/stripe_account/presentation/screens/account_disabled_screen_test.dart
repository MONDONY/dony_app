import 'package:dony/features/stripe_account/presentation/screens/account_disabled_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildWidget() => const MaterialApp(
        home: AccountDisabledScreen(),
      );

  testWidgets('affiche le titre et le message', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('temporairement désactivé'), findsWidgets);
    expect(find.textContaining('réactivation automatique'), findsOneWidget);
  });

  testWidgets('affiche le bouton Stripe dès le premier affichage', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Voir mon compte Stripe'), findsOneWidget);
  });

  testWidgets('bouton support absent au premier affichage', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Contacter le support Dony'), findsNothing);
  });

  testWidgets('bouton support apparaît après 2 taps sur le bouton principal',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Voir mon compte Stripe'));
    await tester.pump();
    expect(find.text('Contacter le support Dony'), findsNothing);
    await tester.tap(find.text('Voir mon compte Stripe'));
    await tester.pump();
    expect(find.text('Contacter le support Dony'), findsOneWidget);
  });
}
