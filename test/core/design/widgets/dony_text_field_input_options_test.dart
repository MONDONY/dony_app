import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Réglages du clavier : valeurs par défaut inchangées, désactivables champ par
/// champ pour un identifiant qu'un correcteur ne doit ni réécrire ni mémoriser.
void main() {
  Future<TextField> pumpField(WidgetTester tester, DonyTextField field) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: field),
      ),
    );
    return tester.widget<TextField>(find.byType(TextField));
  }

  testWidgets('par défaut : correction, suggestions et apprentissage actifs, '
      'aucune majuscule automatique', (tester) async {
    final field = await pumpField(
      tester,
      const DonyTextField(label: 'Nom'), // i18n-ignore: test
    );
    expect(field.autocorrect, isTrue);
    expect(field.enableSuggestions, isTrue);
    expect(field.enableIMEPersonalizedLearning, isTrue);
    expect(field.textCapitalization, TextCapitalization.none);
  });

  testWidgets('réglages transmis au champ de saisie', (tester) async {
    final field = await pumpField(
      tester,
      const DonyTextField(
        label: 'Numéro', // i18n-ignore: test
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        textCapitalization: TextCapitalization.characters,
      ),
    );
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(field.textCapitalization, TextCapitalization.characters);
  });
}
