import 'dart:io';

import 'package:dony/core/design/tokens/typography_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les polices sont embarquées et déclarées dans la table `fonts:` du pubspec.
///
/// Elles passaient par google_fonts, qui téléchargeait chaque variante au premier
/// lancement : l'échec remontait en erreur fatale non capturée et le texte
/// s'affichait en police de repli (Sentry FLUTTER-2, quatorze remontées).
///
/// Le choix de `fonts:` plutôt que `assets:` n'est pas cosmétique. Déclarés en
/// ressources, les fichiers entrent dans le manifeste que lit google_fonts, qui les
/// charge alors avec son propre `FontLoader` y compris sous `flutter test` : le rendu
/// des tests de widgets changeait de police en cours de route, de façon asynchrone
/// donc dépendante du minutage, et un test d'accessibilité qui échantillonne les
/// pixels peints passait en local mais échouait en CI.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final tokens = File(
    'lib/core/design/tokens/typography_tokens.dart',
  ).readAsStringSync();

  /// Les familles que le thème désigne réellement, lues depuis leurs constantes.
  const familles = <String>{
    DonyTypography.fontDisplay,
    DonyTypography.fontBody,
    DonyTypography.fontAccent,
  };

  /// `- asset: assets/fonts/X.ttf` suivi de `weight: N`, dans l'ordre du pubspec.
  List<({String asset, int weight})> declarations() {
    final motif = RegExp(
      r'-\s*asset:\s*(assets/fonts/[\w-]+\.ttf)\s*\n\s*weight:\s*(\d+)',
    );
    return motif
        .allMatches(pubspec)
        .map((m) => (asset: m.group(1)!, weight: int.parse(m.group(2)!)))
        .toList();
  }

  test('les polices sont déclarées en fonts: et jamais en assets:', () {
    expect(
      declarations(),
      isNotEmpty,
      reason: 'table fonts: absente du pubspec',
    );
    expect(
      pubspec.contains('- assets/fonts/\n'),
      isFalse,
      reason:
          'assets/fonts/ en ressources : google_fonts les chargerait aussi '
          'dans les tests de widgets, ce qui rend leur rendu dépendant du minutage',
    );
  });

  test('chaque famille du thème a sa déclaration dans le pubspec', () {
    for (final famille in familles) {
      expect(
        RegExp('family:\\s*$famille').hasMatch(pubspec),
        isTrue,
        reason: 'famille $famille utilisée par le thème mais non déclarée',
      );
    }
  });

  test('chaque fichier déclaré existe vraiment', () {
    final manquants = declarations()
        .map((d) => d.asset)
        .where((asset) => !File(asset).existsSync())
        .toList();

    expect(manquants, isEmpty, reason: 'fichiers déclarés mais absents');
  });

  test('chaque poids demandé par le thème est embarqué', () {
    final embarques = <int>{for (final d in declarations()) d.weight};
    final demandes =
        RegExp(
            r'fontWeight: FontWeight\.w(\d+)',
          ).allMatches(tokens).map((m) => int.parse(m.group(1)!)).toSet()
          // Poids par défaut de `DonyTypography.caveat()`, passé par variable donc
          // invisible au balayage ci-dessus.
          ..add(600);

    expect(
      demandes.difference(embarques),
      isEmpty,
      reason:
          'poids demandés par le thème et non embarqués : le texte '
          'retomberait sur une variante approchée',
    );
  });

  test('google_fonts ne revient pas par la fenêtre', () {
    expect(
      pubspec.contains('google_fonts:'),
      isFalse,
      reason: 'le paquet téléchargeait les polices au démarrage (FLUTTER-2)',
    );
    final appels = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('GoogleFonts.'))
        .map((f) => f.path)
        .toList();

    expect(appels, isEmpty);
  });

  test('chaque police embarquée porte sa licence OFL', () {
    final familles = Directory('assets/fonts')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((nom) => nom.endsWith('.ttf'))
        .map((nom) => nom.split('-').first)
        .toSet();

    expect(familles, isNotEmpty);
    for (final famille in familles) {
      expect(
        File('assets/fonts/licenses/OFL-$famille.txt').existsSync(),
        isTrue,
        reason:
            'licence OFL-$famille.txt manquante : ces polices sont '
            "redistribuées avec l'application, leur licence doit suivre",
      );
    }
  });
}
