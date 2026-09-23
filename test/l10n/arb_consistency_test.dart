import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, String> _messages(String path) {
  final arb = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final e in arb.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };
}

Set<String> _placeholders(String message) =>
    RegExp(r'\{(\w+)[,}]').allMatches(message).map((m) => m.group(1)!).toSet();

/// Clés dont l'anglais est volontairement identique au français.
/// Toute nouvelle entrée doit être justifiée en commentaire.
const _sameInBothLanguages = <String>{
  'commonOk', // « OK » se dit pareil
  'authEmailStepLabel', // « Email » se dit pareil
  'authOnboardingDestinationsEyebrow', // « Destinations » se dit pareil
  // Noms propres identiques en français et en anglais.
  'countryNameFr',
  'countryNameLu',
  'countryNamePt',
  'countryNameCa',
  'countryNameBf',
  'countryNameCi',
  'countryNameMl',
  'countryNameNe',
  'countryNameTg',
  'countryNameCg',
  'countryNameGa',
  'countryZoneEurope',
  'shellTabMessages', // « Messages » se dit pareil
  'shellPlaceholderAdmin', // « Admin » se dit pareil
  'homeFilterChipsDate', // « Date » se dit pareil
  'homeFilterChipsUrgent', // « 🔥 Urgent » se dit pareil
  'homeFilterFieldsTransport', // « TRANSPORT » se dit pareil
  'homeFilterFieldsDate', // « DATE » se dit pareil
  'tripTransportTrain', // « Train » se dit pareil
  'tripTransportBus', // « Bus » se dit pareil
  'paymentMethodMobileMoney', // « Mobile money » se dit pareil
  'requestCreateDateFieldLabel', // « Date » se dit pareil
  'requestCreateBudgetTitle', // « Budget » se dit pareil
  'requestDetailMessageCta', // « Message » se dit pareil
};

void main() {
  final fr = _messages('lib/l10n/app_fr.arb');
  final en = _messages('lib/l10n/app_en.arb');

  test('les deux fichiers ont exactement les mêmes clés', () {
    expect(en.keys.toSet(), fr.keys.toSet());
  });

  test('chaque traduction garde les mêmes paramètres', () {
    for (final key in fr.keys) {
      expect(_placeholders(en[key]!), _placeholders(fr[key]!), reason: key);
    }
  });

  test('aucun texte vide', () {
    for (final entry in [...fr.entries, ...en.entries]) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
    }
  });

  test('aucun tiret cadratin', () {
    for (final entry in [...fr.entries, ...en.entries]) {
      expect(entry.value.contains('—'), isFalse, reason: entry.key);
    }
  });

  test('la marque affichée est Yadony, jamais Dony', () {
    final dony = RegExp(r'(?<![A-Za-z])Dony\b');
    for (final entry in [...fr.entries, ...en.entries]) {
      expect(dony.hasMatch(entry.value), isFalse, reason: entry.key);
    }
  });

  test("l'anglais est traduit (pas une copie du français)", () {
    for (final key in fr.keys) {
      if (_sameInBothLanguages.contains(key)) continue;
      expect(en[key], isNot(fr[key]), reason: key);
    }
  });
}
