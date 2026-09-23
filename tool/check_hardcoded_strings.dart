// ignore_for_file: avoid_print
import 'dart:io';

/// Garde-fou i18n : compte les lignes de `lib/` (couches d'affichage et
/// design system) qui contiennent encore un texte français écrit en dur.
///
/// Le compte ne peut que baisser : il est comparé au seuil enregistré dans
/// `tool/hardcoded_strings_baseline.txt`. Une PR qui ajoute du français en
/// dur fait échouer la CI ; une PR qui en retire doit abaisser le seuil.
///
/// Heuristique volontairement simple : une ligne compte si elle contient un
/// littéral de chaîne qui porte une lettre accentuée française ou un mot
/// outil français courant. Les commentaires sont ignorés, et une ligne
/// marquée `// i18n-ignore` aussi (nom propre, exemple de numéro…).

final _literal = RegExp(
  r"'(?:[^'\\\n]|\\.)*'"
  '|'
  r'"(?:[^"\\\n]|\\.)*"',
);
final _accent = RegExp('[àâäçéèêëîïôöùûüÿœæÀÂÇÉÈÊÎÔÙÛŒ]');
final _frenchWord = RegExp(
  r"(^|[\s'’])(le|la|les|de|du|des|un|une|ton|ta|tes|votre|vos|pour|avec|sur|dans|pas|est)(?=\s)",
  caseSensitive: false,
);

final _debugLog = RegExp(r'\b(debugPrint|log|print)\(');

bool _isInScope(String relPath) =>
    relPath.contains('/presentation/') ||
    relPath.startsWith('lib/core/design/');

/// Nombre de lignes de [source] qui portent un texte français en dur.
int countHardcodedFrench(String source) {
  var count = 0;
  for (final line in source.split('\n')) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//') || trimmed.startsWith('import ')) continue;
    if (line.contains('// i18n-ignore')) continue;
    // Journaux de debug : jamais affichés à l'utilisateur.
    if (_debugLog.hasMatch(line)) continue;
    final code = _stripTrailingComment(line);
    final hit = _literal.allMatches(code).any((m) {
      final text = m.group(0)!;
      final body = text.substring(1, text.length - 1);
      return _accent.hasMatch(body) || _frenchWord.hasMatch(body);
    });
    if (hit) count++;
  }
  return count;
}

String _stripTrailingComment(String line) {
  // Retire un « // commentaire » situé hors d'un littéral.
  var inSingle = false, inDouble = false;
  for (var i = 0; i < line.length - 1; i++) {
    final c = line[i];
    if (c == '\\') {
      i++;
      continue;
    }
    if (c == "'" && !inDouble) inSingle = !inSingle;
    if (c == '"' && !inSingle) inDouble = !inDouble;
    if (!inSingle && !inDouble && c == '/' && line[i + 1] == '/') {
      return line.substring(0, i);
    }
  }
  return line;
}

/// Total sur tous les fichiers `.dart` non générés de [libDir] en périmètre.
int countInLib(Directory libDir) {
  var total = 0;
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final rel = entity.path.replaceAll('\\', '/');
    final relFromLib = rel.substring(rel.indexOf('lib/'));
    if (relFromLib.endsWith('.g.dart') || relFromLib.contains('/generated/')) {
      continue;
    }
    if (!_isInScope(relFromLib)) continue;
    total += countHardcodedFrench(entity.readAsStringSync());
  }
  return total;
}

void main(List<String> args) {
  final baselineFile = File('tool/hardcoded_strings_baseline.txt');
  final count = countInLib(Directory('lib'));
  if (args.contains('--print')) {
    print(count);
    return;
  }
  final baseline = int.parse(baselineFile.readAsStringSync().trim());
  if (count > baseline) {
    print(
      'Textes français en dur : $count (seuil $baseline). '
      'Passe les nouveaux textes par context.l10n (lib/l10n/app_fr.arb).',
    );
    exit(1);
  }
  if (count < baseline) {
    print(
      'Textes français en dur : $count, sous le seuil $baseline. '
      'Abaisse tool/hardcoded_strings_baseline.txt à $count.',
    );
    exit(1);
  }
  print('Textes français en dur : $count (seuil $baseline) OK');
}
