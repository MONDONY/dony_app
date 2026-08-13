// E2E DIAGNOSTIC : création demande d'envoi — logue les textes visibles à
// chaque étape pour caler les finders. Assertions souples (sauf succès final).
import 'package:dony/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/app_driver.dart';

void _dumpTexts(String tag) {
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .where((d) => d != null && d.trim().isNotEmpty)
      .toList();
  debugPrint('=== VISIBLE[$tag] (${texts.length}): $texts');
}

Future<void> _settle(WidgetTester t, [int ms = 1500]) async {
  await t.pump(const Duration(milliseconds: 300));
  await t.pump(Duration(milliseconds: ms));
}

Future<void> _pickCity(WidgetTester t, int fieldIndex, String query) async {
  final fields = find.byType(TextField);
  if (fields.evaluate().length <= fieldIndex) {
    debugPrint('=== PICKCITY[$query]: champ index $fieldIndex absent (${fields.evaluate().length} TextField)');
    return;
  }
  await t.enterText(fields.at(fieldIndex), query);
  await _settle(t, 2500);
  _dumpTexts('apres-saisie-$query');
  final result = find.widgetWithText(ListTile, query);
  if (result.evaluate().isNotEmpty) {
    await t.tap(result.first);
  } else {
    debugPrint('=== PICKCITY[$query]: aucun ListTile résultat');
  }
  await _settle(t);
}

Future<void> _tapText(WidgetTester t, String label) async {
  final f = find.text(label);
  if (f.evaluate().isNotEmpty) {
    await t.tap(f.first);
    debugPrint('=== TAP ok: "$label"');
  } else {
    debugPrint('=== TAP introuvable: "$label"');
  }
  await _settle(t, 2000);
}

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E création demande (diagnostic)', (tester) async {
    await launchAndReady(tester);
    _dumpTexts('accueil');

    appRouter.go('/package-requests/new');
    await _settle(tester, 3000);
    _dumpTexts('apres-route-new');

    await _pickCity(tester, 0, 'Paris');
    await _pickCity(tester, 1, 'Dakar');
    _dumpTexts('apres-villes');

    await _tapText(tester, 'Date');
    _dumpTexts('date-picker');
    await _tapText(tester, 'OK');

    await _tapText(tester, 'Continuer');
    _dumpTexts('etape2');

    final tf = find.byType(TextFormField);
    if (tf.evaluate().isNotEmpty) {
      await tester.enterText(tf.first, '5');
      await _settle(tester);
    }
    await _tapText(tester, 'Vêtements');
    await _tapText(tester, 'Continuer');
    _dumpTexts('etape3');

    final budget = find.byKey(const Key('total-budget-input'));
    if (budget.evaluate().isNotEmpty) {
      await tester.enterText(budget, '40');
      await _settle(tester);
    }
    await _tapText(tester, 'Publier ma demande');
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester, 4000);
    _dumpTexts('apres-publier');

    final success = find.textContaining('Demande publiée');
    debugPrint('=== SUCCESS FINDER: ${success.evaluate().length} match');
  });
}
