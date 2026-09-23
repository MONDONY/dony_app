import 'package:test/test.dart';

import '../../tool/check_hardcoded_strings.dart';

void main() {
  test('littéral accentué → compté', () {
    expect(countHardcodedFrench("Text('Paramètres'),"), 1);
  });

  test('mot outil français → compté', () {
    expect(countHardcodedFrench("label: 'Voir le trajet',"), 1);
  });

  test('texte anglais ou clé → ignoré', () {
    expect(countHardcodedFrench("final k = 'language_code';"), 0);
    expect(countHardcodedFrench("Text(context.l10n.commonClose),"), 0);
  });

  test('commentaires ignorés, y compris en fin de ligne', () {
    expect(countHardcodedFrench('// Écran des réglages'), 0);
    expect(countHardcodedFrench('/// Préférences'), 0);
    expect(countHardcodedFrench("final x = 1; // 'déjà'"), 0);
  });

  test('ligne marquée i18n-ignore → ignorée', () {
    expect(countHardcodedFrench("hint: 'Aminata Diallo', // i18n-ignore"), 0);
  });

  test('journaux de debug ignorés', () {
    expect(countHardcodedFrench("debugPrint('échec de la requête');"), 0);
  });

  test('une ligne compte une fois même avec deux littéraux', () {
    expect(
      countHardcodedFrench("Row(children: [Text('Été'), Text('Hiver à')])"),
      1,
    );
  });
}
