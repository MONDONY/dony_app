import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DonyTextField', () {
    testWidgets('transmet la touche d\'action au clavier', (tester) async {
      // Le composant du design system ne l'exposait pas : aucun écran ne
      // pouvait donc offrir un bouton « suivant », quel que soit son code.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: DonyTextField(
              label: 'Ville',
              textInputAction: TextInputAction.next,
            ),
          ),
        ),
      );
      final champ = tester.widget<TextField>(find.byType(TextField));
      expect(champ.textInputAction, TextInputAction.next);
    });

    testWidgets('passe au champ suivant à la validation clavier', (
      tester,
    ) async {
      // Vérifie le comportement, pas seulement la déclaration : `next` doit
      // réellement déplacer le focus.
      final premier = FocusNode();
      final second = FocusNode();
      addTearDown(premier.dispose);
      addTearDown(second.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                DonyTextField(
                  label: 'Prénom',
                  focusNode: premier,
                  textInputAction: TextInputAction.next,
                ),
                DonyTextField(label: 'Nom', focusNode: second),
              ],
            ),
          ),
        ),
      );

      premier.requestFocus();
      await tester.pump();
      expect(premier.hasFocus, isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      expect(second.hasFocus, isTrue, reason: 'le focus doit avancer');
      expect(premier.hasFocus, isFalse);
    });

    testWidgets('la variante tappable n\'a pas de touche d\'action', (
      tester,
    ) async {
      // Elle ouvre un sélecteur, jamais un clavier.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DonyTextField.tappable(
              label: 'Date',
              value: '12 mars',
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byType(TextField), findsNothing);
    });
  });

  test('les formulaires linéaires chaînent leurs champs', () {
    // Garde-fou de sources : un champ ajouté au milieu d'un de ces formulaires
    // sans touche d'action romprait la chaîne en silence, et aucun test de
    // widget ne le verrait sans monter l'écran entier avec ses dépendances.
    const formulaires = <String, int>{
      'lib/features/pickup_addresses/presentation/screens/pickup_address_edit_screen.dart':
          4,
      // Le champ email (textInputAction: next) est sorti de ce formulaire :
      // sa modification passe désormais par un écran OTP dédié, pas par une
      // saisie libre chaînée ici. Reste prénom → nom → ville.
      'lib/features/profile/presentation/screens/edit_profile_screen.dart': 3,
      // Ce formulaire n'a réellement que 3 champs texte (nom, téléphone,
      // ville) — rien ne suit la ville, pas de 4e champ à chaîner.
      'lib/features/package_request/presentation/screens/sender/complete_details_screen.dart':
          3,
      'lib/features/delivery_addresses/presentation/screens/delivery_address_edit_screen.dart':
          2,
    };

    formulaires.forEach((chemin, attendu) {
      final source = File(chemin).readAsStringSync();
      final trouve = RegExp('textInputAction:').allMatches(source).length;
      expect(
        trouve,
        greaterThanOrEqualTo(attendu),
        reason:
            '$chemin : $trouve champs chaînés, $attendu attendus au minimum',
      );
      expect(
        source.contains('TextInputAction.done'),
        isTrue,
        reason:
            '$chemin : le dernier champ doit conclure par « done », '
            'sinon le clavier propose d\'avancer vers rien',
      );
    });
  });
}
