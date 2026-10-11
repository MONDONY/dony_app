import 'dart:convert';
import 'dart:io';

import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'all_messages_catalog.g.dart';

/// Rend chaque message français et anglais de l'app, tel que l'écran le
/// recevra, et vérifie ce que `arb_consistency_test.dart` ne voit pas depuis
/// l'ARB brut : le texte produit par le code généré.
///
/// - aucun message rendu n'est vide ;
/// - chaque paramètre texte écrit `{nom}` dans la traduction se retrouve
///   dans le texte rendu (une valeur perdue à l'interpolation afficherait
///   « Colis envoyé à  » sans le nom) ;
/// - aucun `{nom}` ne reste brut dans le texte rendu (paramètre mal déclaré,
///   accolade non échappée).
///
/// Le catalogue `all_messages_catalog.g.dart` se régénère avec
/// `dart run tool/gen_l10n_catalog.dart`.
void main() {
  final template = _readArb('lib/l10n/app_fr.arb');
  final rawPlaceholder = RegExp(r'\{\w+\}');

  test('le catalogue décrit des messages de l\'ARB', () {
    final arbKeys = template.keys.where((k) => !k.startsWith('@')).toSet();
    expect(allMessages, isNotEmpty);
    expect(arbKeys.containsAll(allMessages.keys), isTrue);
  });

  for (final code in ['fr', 'en']) {
    test('chaque message $code se rend avec ses paramètres', () {
      final arb = _readArb('lib/l10n/app_$code.arb');
      final l = lookupAppLocalizations(Locale(code));
      expect(l.localeName, code);

      final failures = <String>[];
      allMessages.forEach((key, render) {
        final text = render(l);
        if (text.trim().isEmpty) failures.add('$key : texte vide');

        final message = arb[key] as String? ?? '';
        // Un paramètre de `select` n'apparaît pas tel quel (`{mode, select,
        // …}`) : seul un `{nom}` simple doit se retrouver dans le texte.
        for (final name in textParameters[key] ?? const <String>[]) {
          if (message.contains('{$name}') &&
              !text.contains(placeholderMarker(name))) {
            failures.add('$key : paramètre {$name} perdu dans « $text »');
          }
        }

        final raw = rawPlaceholder.firstMatch(text);
        if (raw != null) {
          failures.add('$key : ${raw.group(0)} resté brut dans « $text »');
        }
      });

      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }

  test('les messages anglais diffèrent du français', () {
    // Garde-fou grossier contre une traduction anglaise recopiée du
    // français : la grande majorité des messages doit changer de texte.
    final fr = lookupAppLocalizations(const Locale('fr'));
    final en = lookupAppLocalizations(const Locale('en'));
    final identical = allMessages.entries
        .where((e) => e.value(fr) == e.value(en))
        .length;
    expect(identical / allMessages.length, lessThan(0.1));
  });
}

Map<String, dynamic> _readArb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
