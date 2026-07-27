import 'package:dony/features/payments/presentation/widgets/escrow_explainer_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche le montant et le nom du voyageur', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => TextButton(
        onPressed: () => EscrowExplainerBottomSheet.show(
          ctx,
          amount: 150.0,
          travelerName: 'Amadou Diallo',
        ),
        child: const Text('Ouvrir'),
      )),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    // Le format exact peut varier selon la locale, on cherche les composants principaux
    expect(find.textContaining('150'), findsWidgets);
    expect(find.textContaining('€'), findsOneWidget);
    expect(find.text('Amadou Diallo'), findsOneWidget);
    expect(find.text("J'ai compris"), findsOneWidget);
  });

  testWidgets('affiche les trois explications escrow', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => TextButton(
        onPressed: () => EscrowExplainerBottomSheet.show(
          ctx,
          amount: 100.0,
          travelerName: 'Fatou',
        ),
        child: const Text('Ouvrir'),
      )),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text("Votre paiement est bloqué en séquestre jusqu'à confirmation de livraison par le destinataire."), findsOneWidget);
    expect(find.text('Libération automatique 48h après la date de livraison prévue si aucune confirmation.'), findsOneWidget);
    expect(find.text('En cas de litige, yadony intervient pour arbitrer et protéger les deux parties.'), findsOneWidget);
  });
}
