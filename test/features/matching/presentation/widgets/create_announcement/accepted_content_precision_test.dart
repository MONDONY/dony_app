import 'package:dony/features/matching/presentation/widgets/create_announcement/prix_conditions_step.dart';
import 'package:flutter_test/flutter_test.dart';

// FLUTTER-4G : « Autre » coché exige une précision, qui le remplace.
void main() {
  test('sans « Autre » : contenus tels quels', () {
    expect(
      acceptedContentWithPrecision(
        selected: {'Vêtements & tissus'},
        custom: {'Pièces auto'},
        otherPrecision: '',
      ),
      unorderedEquals(['Vêtements & tissus', 'Pièces auto']),
    );
  });

  test('« Autre » sans précision : null (publication bloquée)', () {
    expect(
      acceptedContentWithPrecision(
        selected: {'Autre'},
        custom: const {},
        otherPrecision: '   ',
      ),
      isNull,
    );
  });

  test('« Autre » avec précision : remplacé par la précision', () {
    expect(
      acceptedContentWithPrecision(
        selected: {'Autre', 'Livres'},
        custom: const {},
        otherPrecision: ' Pièces, auto ',
      ),
      unorderedEquals(['Livres', 'Pièces auto']),
    );
  });

  test('rien de coché : liste vide (tout accepté)', () {
    expect(
      acceptedContentWithPrecision(
        selected: const {},
        custom: const {},
        otherPrecision: '',
      ),
      isEmpty,
    );
  });
}
