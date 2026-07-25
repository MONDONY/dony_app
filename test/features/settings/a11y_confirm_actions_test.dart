import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child, {required bool confirm}) => MaterialApp(
      theme: AppTheme.light(),
      home: AccessibilityScope(
        underlineLinks: false,
        reinforceLabels: false,
        persistentMessages: false,
        confirmImportantActions: confirm,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  testWidgets('sans l\'option, l\'action passe sans dialogue', (tester) async {
    bool? result;
    await tester.pumpWidget(wrap(
      Builder(builder: (ctx) {
        return TextButton(
          onPressed: () async {
            result = await confirmImportantAction(
              ctx,
              title: 'Confirmer le paiement',
              message: 'Le montant sera bloqué jusqu\'à la livraison.',
            );
          },
          child: const Text('Payer'),
        );
      }),
      confirm: false,
    ));
    await tester.tap(find.text('Payer'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('Confirmer le paiement'), findsNothing);
  });

  testWidgets('avec l\'option, un dialogue s\'intercale', (tester) async {
    bool? result;
    await tester.pumpWidget(wrap(
      Builder(builder: (ctx) {
        return TextButton(
          onPressed: () async {
            result = await confirmImportantAction(
              ctx,
              title: 'Confirmer le paiement',
              message: 'Le montant sera bloqué jusqu\'à la livraison.',
            );
          },
          child: const Text('Payer'),
        );
      }),
      confirm: true,
    ));
    await tester.tap(find.text('Payer'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmer le paiement'), findsOneWidget);
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('refuser le dialogue annule l\'action', (tester) async {
    bool? result;
    await tester.pumpWidget(wrap(
      Builder(builder: (ctx) {
        return TextButton(
          onPressed: () async {
            result = await confirmImportantAction(
              ctx,
              title: 'Confirmer le paiement',
              message: 'Le montant sera bloqué jusqu\'à la livraison.',
            );
          },
          child: const Text('Payer'),
        );
      }),
      confirm: true,
    ));
    await tester.tap(find.text('Payer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
