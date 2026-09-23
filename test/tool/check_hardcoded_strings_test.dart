import 'dart:io';

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
    expect(countHardcodedFrench('Text(context.l10n.commonClose),'), 0);
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

  test('readBaseline: fichier avec "42\\n" → 42', () {
    final tempDir = Directory.systemTemp.createTempSync();
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final file = File('${tempDir.path}/baseline.txt');
    file.writeAsStringSync('42\n');
    expect(readBaseline(file), 42);
  });

  test('readBaseline: fichier absent → null', () {
    final tempDir = Directory.systemTemp.createTempSync();
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final file = File('${tempDir.path}/nonexistent.txt');
    expect(readBaseline(file), null);
  });

  test('readBaseline: fichier avec "abc" → null', () {
    final tempDir = Directory.systemTemp.createTempSync();
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final file = File('${tempDir.path}/baseline.txt');
    file.writeAsStringSync('abc');
    expect(readBaseline(file), null);
  });
}
