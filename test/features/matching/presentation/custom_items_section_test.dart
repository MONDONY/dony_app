import 'package:dony/features/matching/presentation/widgets/custom_items_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(
  ValueNotifier<List<BidCustomItemDraft>> notifier, {
  String currencyCode = 'EUR',
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: CustomItemsSection(
        notifier: notifier,
        currencyCode: currencyCode,
      ),
    ),
  ),
);

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('custom-item-add')));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _fillForm(
  WidgetTester tester, {
  required String label,
  required String amount,
}) async {
  await tester.enterText(find.byKey(const Key('custom-item-label')), label);
  await tester.pump(const Duration(milliseconds: 600));
  await tester.enterText(find.byKey(const Key('custom-item-amount')), amount);
  await tester.pump(const Duration(milliseconds: 600));
  // Le bouton du `stickyBottom` est armé via `addPostFrameCallback` : il faut
  // une frame de plus pour que le `ValueListenableBuilder` en tienne compte.
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('l etat vide affiche l invite et aucune ligne', (tester) async {
    final notifier = ValueNotifier<List<BidCustomItemDraft>>([]);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(_wrap(notifier));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const Key('custom-items-empty')), findsOneWidget);
    expect(find.byKey(const Key('custom-item-row-0')), findsNothing);
    expect(find.byKey(const Key('custom-items-total')), findsNothing);
  });

  testWidgets('ajouter une ligne l affiche et alimente le notifier', (
    tester,
  ) async {
    final notifier = ValueNotifier<List<BidCustomItemDraft>>([]);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(_wrap(notifier));
    await tester.pump(const Duration(milliseconds: 600));

    await _openForm(tester);
    await _fillForm(tester, label: 'Sac de riz', amount: '9');
    await tester.tap(find.byKey(const Key('custom-item-submit')));
    await tester.pump(const Duration(milliseconds: 600));
    // Seconde frame : laisse la feuille finir son animation de fermeture,
    // sinon son champ de saisie compte encore pour une occurrence du libellé.
    await tester.pump(const Duration(milliseconds: 600));

    expect(notifier.value, hasLength(1));
    expect(notifier.value.first.label, 'Sac de riz');
    expect(notifier.value.first.amountEur, 9);
    expect(notifier.value.first.quantity, 1);
    expect(find.byKey(const Key('custom-item-row-0')), findsOneWidget);
    expect(find.text('Sac de riz'), findsOneWidget);
    expect(find.byKey(const Key('custom-items-empty')), findsNothing);
  });

  testWidgets('supprimer une ligne la retire', (tester) async {
    final notifier = ValueNotifier<List<BidCustomItemDraft>>([
      BidCustomItemDraft(label: 'Sac de riz', quantity: 1, amountEur: 9),
      BidCustomItemDraft(label: 'Boubou', quantity: 1, amountEur: 12),
    ]);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(_wrap(notifier));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byKey(const Key('custom-item-remove-0')));
    await tester.pump(const Duration(milliseconds: 600));

    expect(notifier.value, hasLength(1));
    expect(notifier.value.single.label, 'Boubou');
    expect(find.text('Sac de riz'), findsNothing);
  });

  testWidgets('le total de la section tient compte des quantites', (
    tester,
  ) async {
    final notifier = ValueNotifier<List<BidCustomItemDraft>>([
      BidCustomItemDraft(label: 'Sac de riz', quantity: 2, amountEur: 9),
      BidCustomItemDraft(label: 'Boubou', quantity: 1, amountEur: 12.5),
    ]);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(_wrap(notifier));
    await tester.pump(const Duration(milliseconds: 600));

    expect(customItemsTotalEur(notifier.value), 30.5);
    final total = tester.widget<Text>(
      find.byKey(const Key('custom-items-total')),
    );
    expect(total.data, contains('30,50'));
  });

  testWidgets('le total se recalcule apres une suppression', (tester) async {
    final notifier = ValueNotifier<List<BidCustomItemDraft>>([
      BidCustomItemDraft(label: 'Sac de riz', quantity: 2, amountEur: 9),
      BidCustomItemDraft(label: 'Boubou', quantity: 1, amountEur: 12.5),
    ]);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(_wrap(notifier));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byKey(const Key('custom-item-remove-1')));
    await tester.pump(const Duration(milliseconds: 600));

    final total = tester.widget<Text>(
      find.byKey(const Key('custom-items-total')),
    );
    // `\s` et non une espace littérale : `intl` sépare montant et symbole par
    // une espace insécable.
    expect(total.data, matches(RegExp(r'^18\s€$')));
  });

  // Le trajet fige sa devise à la publication : un montant en franc CFA
  // affiché « € » ment sur le prix, et c'est exactement la régression que la
  // cohérence multidevise avait supprimée ailleurs dans l'app.
  testWidgets('aucun symbole euro sur un trajet en devise etrangere', (
    tester,
  ) async {
    final notifier = ValueNotifier<List<BidCustomItemDraft>>([
      BidCustomItemDraft(label: 'Sac de riz', quantity: 2, amountEur: 6000),
    ]);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(_wrap(notifier, currencyCode: 'XOF'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('€', findRichText: true), findsNothing);
    final total = tester.widget<Text>(
      find.byKey(const Key('custom-items-total')),
    );
    expect(total.data, contains('F CFA'));
    expect(find.textContaining('F CFA'), findsWidgets);

    // Le champ de saisie du formulaire d'ajout porte la même devise : « Prix
    // (€) » y ferait saisir un montant dans une unité qui n'est pas celle du
    // trajet.
    await _openForm(tester);
    expect(find.textContaining('€', findRichText: true), findsNothing);
    expect(
      find.textContaining('Prix (F CFA)', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('une ligne sans libelle n est pas ajoutable', (tester) async {
    final notifier = ValueNotifier<List<BidCustomItemDraft>>([]);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(_wrap(notifier));
    await tester.pump(const Duration(milliseconds: 600));

    await _openForm(tester);
    await _fillForm(tester, label: '   ', amount: '9');

    final button = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('custom-item-submit')),
        matching: find.byType(InkWell),
      ),
    );
    expect(button.onTap, isNull);

    await tester.tap(find.byKey(const Key('custom-item-submit')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(notifier.value, isEmpty);
  });

  testWidgets('une ligne a montant nul n est pas ajoutable', (tester) async {
    final notifier = ValueNotifier<List<BidCustomItemDraft>>([]);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(_wrap(notifier));
    await tester.pump(const Duration(milliseconds: 600));

    await _openForm(tester);
    await _fillForm(tester, label: 'Sac de riz', amount: '0');

    await tester.tap(find.byKey(const Key('custom-item-submit')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(notifier.value, isEmpty);
  });

  test('toJson expose le contrat attendu par le backend', () {
    final draft = BidCustomItemDraft(
      label: 'Sac de riz',
      quantity: 2,
      amountEur: 9.5,
    );
    expect(draft.toJson(), {
      'label': 'Sac de riz',
      'quantity': 2,
      'amountEur': 9.5,
    });
  });

  test('le total est nul sur une liste vide', () {
    expect(customItemsTotalEur(const []), 0);
  });
}
