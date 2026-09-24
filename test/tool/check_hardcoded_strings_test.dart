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

  group('isInScope', () {
    test('tout lib/ compte, y compris data/', () {
      expect(isInScope('lib/features/x/data/y.dart'), isTrue);
      expect(isInScope('lib/features/x/presentation/y.dart'), isTrue);
      expect(isInScope('lib/core/error/error_catalog.dart'), isTrue);
    });
    test('lib/l10n/ exclu', () {
      expect(isInScope('lib/l10n/l10n.dart'), isFalse);
      expect(isInScope('lib/l10n/generated/a.dart'), isFalse);
    });
    test('fichiers générés exclus', () {
      expect(isInScope('lib/x.g.dart'), isFalse);
      expect(isInScope('lib/features/x/generated/a.dart'), isFalse);
    });
  });

  group('verdict', () {
    test('au seuil → 0, OK', () {
      final v = verdict(10, 10);
      expect(v.exitCode, 0);
      expect(v.message, contains('OK'));
    });
    test('au-dessus du seuil → 1', () {
      expect(verdict(11, 10).exitCode, 1);
    });
    test('sous le seuil → 0 avec invitation à abaisser le seuil', () {
      final v = verdict(8, 10);
      expect(v.exitCode, 0);
      expect(v.message, contains('Abaisse'));
      expect(v.message, contains('8'));
    });
    test('seuil illisible → 1', () {
      expect(verdict(8, null).exitCode, 1);
    });
  });
}
