import 'dart:ui' show Tristate;

import 'package:dony/core/design/widgets/dony_expandable_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Mode { card, mobileMoney, cash }

List<DonyChoice<_Mode>> _choices() => [
  DonyChoice(
    value: _Mode.card,
    title: 'Carte',
    subtitle: 'Visa, Mastercard, PayPal',
    iconAsset: 'credit-card',
    key: const Key('c-card'),
    expanded: (_) => const Text('contenu carte', key: Key('x-card')),
  ),
  DonyChoice(
    value: _Mode.mobileMoney,
    title: 'Mobile money',
    subtitle: 'Orange Money, Wave, MTN',
    iconAsset: 'smartphone',
    key: const Key('c-mm'),
    expanded: (_) => const Text('contenu mobile money', key: Key('x-mm')),
  ),
  DonyChoice(
    value: _Mode.cash,
    title: 'Espèces',
    subtitle: 'À la remise',
    iconAsset: 'banknote',
    key: const Key('c-cash'),
    expanded: (_) => const Text('contenu espèces', key: Key('x-cash')),
  ),
];

Widget _host({
  required _Mode value,
  required ValueChanged<_Mode> onChanged,
  List<DonyChoice<_Mode>>? choices,
  double textScale = 1.0,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: DonyExpandableChoice<_Mode>(
            choices: choices ?? _choices(),
            value: value,
            onChanged: onChanged,
            enableHaptic: false,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('chaque carte montre sa clé, son titre et son résumé', (
    tester,
  ) async {
    await tester.pumpWidget(_host(value: _Mode.card, onChanged: (_) {}));

    for (final k in ['c-card', 'c-mm', 'c-cash']) {
      expect(find.byKey(Key(k)), findsOneWidget);
    }
    expect(find.text('Mobile money'), findsOneWidget);
    expect(find.text('Orange Money, Wave, MTN'), findsOneWidget);
    expect(find.text('Espèces'), findsOneWidget);
  });

  testWidgets('seul le choix retenu construit son contenu ouvert', (
    tester,
  ) async {
    await tester.pumpWidget(_host(value: _Mode.mobileMoney, onChanged: (_) {}));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('x-mm')), findsOneWidget);
    expect(find.byKey(const Key('x-card')), findsNothing);
    expect(find.byKey(const Key('x-cash')), findsNothing);
  });

  testWidgets('un tap sur une autre carte remonte sa valeur', (tester) async {
    _Mode? recu;
    await tester.pumpWidget(
      _host(value: _Mode.card, onChanged: (v) => recu = v),
    );

    await tester.tap(find.byKey(const Key('c-cash')));
    await tester.pumpAndSettle();

    expect(recu, _Mode.cash);
  });

  testWidgets('un tap sur la carte déjà retenue ne remonte rien', (
    tester,
  ) async {
    var appels = 0;
    await tester.pumpWidget(
      _host(value: _Mode.card, onChanged: (_) => appels++),
    );

    await tester.tap(find.byKey(const Key('c-card')));
    await tester.pumpAndSettle();

    expect(appels, 0);
  });

  testWidgets(
    'la carte retenue est annoncée sélectionnée aux lecteurs d\'écran',
    (tester) async {
      await tester.pumpWidget(
        _host(value: _Mode.mobileMoney, onChanged: (_) {}),
      );

      final retenue = tester.getSemantics(find.byKey(const Key('c-mm')));
      expect(retenue.flagsCollection.isSelected, Tristate.isTrue);
      expect(retenue.flagsCollection.isButton, isTrue);

      final autre = tester.getSemantics(find.byKey(const Key('c-card')));
      expect(autre.flagsCollection.isSelected, isNot(Tristate.isTrue));
    },
  );

  testWidgets('un seul choix : ouvert d\'office, sans radio, clé conservée', (
    tester,
  ) async {
    var appels = 0;
    await tester.pumpWidget(
      _host(
        value: _Mode.card,
        onChanged: (_) => appels++,
        choices: _choices().sublist(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('c-cash')), findsOneWidget);
    expect(find.byKey(const Key('x-cash')), findsOneWidget);

    await tester.tap(find.byKey(const Key('c-cash')));
    await tester.pumpAndSettle();
    expect(appels, 0);
  });

  testWidgets('à 200 % de taille de texte, rien ne déborde', (tester) async {
    await tester.pumpWidget(
      _host(value: _Mode.mobileMoney, onChanged: (_) {}, textScale: 2.0),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Mobile money'), findsOneWidget);
  });
}
