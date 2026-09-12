import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

  testWidgets('affiche pastille, titre, sous-titre et case cochée', (
    tester,
  ) async {
    await pump(
      tester,
      DonyOperatorTile(
        brand: 'ORANGE',
        title: 'Orange Money',
        subtitle: 'Détecté pour ce numéro',
        control: DonyOperatorControl.checkbox,
        selected: true,
        onChanged: (_) {},
      ),
    );
    expect(find.text('Orange Money'), findsOneWidget);
    expect(find.text('Détecté pour ce numéro'), findsOneWidget);
    expect(find.byType(DonyBrandMark), findsOneWidget);
    expect(find.byKey(const Key('operator-control-selected')), findsOneWidget);
  });

  testWidgets('sans marque : pas de pastille (ligne « Tous les réseaux »)', (
    tester,
  ) async {
    await pump(
      tester,
      DonyOperatorTile(
        title: 'Tous les réseaux',
        control: DonyOperatorControl.checkbox,
        selected: false,
        indeterminate: true,
        onChanged: (_) {},
      ),
    );
    expect(find.byType(DonyBrandMark), findsNothing);
    expect(
      find.byKey(const Key('operator-control-unselected')),
      findsOneWidget,
    );
  });

  testWidgets('un tap sur la ligne inverse la sélection', (tester) async {
    bool? received;
    await pump(
      tester,
      DonyOperatorTile(
        brand: 'WAVE',
        title: 'Wave',
        control: DonyOperatorControl.radio,
        selected: false,
        onChanged: (v) => received = v,
      ),
    );
    await tester.tap(find.text('Wave'));
    expect(received, isTrue);
  });

  testWidgets('désactivée : aucun rappel au tap', (tester) async {
    var calls = 0;
    await pump(
      tester,
      DonyOperatorTile(
        brand: 'WAVE',
        title: 'Wave',
        control: DonyOperatorControl.checkbox,
        selected: false,
        enabled: false,
        onChanged: (_) => calls++,
      ),
    );
    await tester.tap(find.text('Wave'));
    expect(calls, 0);
  });

  testWidgets('la ligne fait au moins 44 px de haut', (tester) async {
    await pump(
      tester,
      DonyOperatorTile(
        title: 'Wave',
        control: DonyOperatorControl.radio,
        selected: false,
        onChanged: (_) {},
      ),
    );
    expect(
      tester.getSize(find.byType(DonyOperatorTile)).height,
      greaterThanOrEqualTo(44),
    );
  });
}
