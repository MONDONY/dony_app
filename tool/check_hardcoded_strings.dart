// ignore_for_file: avoid_print
import 'dart:io';

/// Garde-fou i18n : compte les lignes de `lib/` qui contiennent encore un
/// texte français écrit en dur. Périmètre : tout `lib/**`, sauf `lib/l10n/**`
/// (les traductions elles-mêmes), les dossiers `generated/` et les fichiers
/// `*.g.dart`.
///
/// Le compte est comparé au seuil enregistré dans
/// `tool/hardcoded_strings_baseline.txt`. Au-dessus du seuil, la CI échoue :
/// la PR a ajouté du français en dur. Sous le seuil, le script réussit mais
/// affiche un avertissement qui invite à abaisser le seuil au nouveau compte.
///
/// Heuristique volontairement simple : une ligne compte si elle contient un
/// littéral de chaîne qui porte une lettre accentuée française ou un mot
/// outil français courant. Les commentaires sont ignorés, et une ligne
/// marquée `// i18n-ignore` aussi (nom propre, exemple de numéro…).
///
/// Limites connues :
/// - un verbe isolé sans accent (« Continuer », « Envoyer ») n'est pas
///   détecté ;
/// - un texte anglais qui contient « pour » ou « sur » (« pour-over »,
///   « sur place » en citation…) est compté à tort.

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

/// Vrai si [relPath] (chemin relatif commençant par `lib/`) est surveillé.
bool isInScope(String relPath) =>
    relPath.startsWith('lib/') &&
    !relPath.startsWith('lib/l10n/') &&
    !relPath.contains('/generated/') &&
    !relPath.endsWith('.g.dart');

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
    if (!isInScope(relFromLib)) continue;
    total += countHardcodedFrench(entity.readAsStringSync());
  }
  return total;
}

/// Lit le seuil depuis [file], ou renvoie `null` si absent ou mal formé.
int? readBaseline(File file) {
  try {
    if (!file.existsSync()) return null;
    final content = file.readAsStringSync().trim();
    return int.tryParse(content);
  } catch (_) {
    return null;
  }
}

/// Code de sortie et message du garde-fou pour [count] face au seuil
/// [baseline] (`null` si le fichier de seuil est illisible). Échec (1)
/// seulement au-dessus du seuil ou sans seuil ; sous le seuil, réussite (0)
/// avec un avertissement.
({int exitCode, String message}) verdict(int count, int? baseline) {
  if (baseline == null) {
    return (
      exitCode: 1,
      message:
          'Seuil illisible : tool/hardcoded_strings_baseline.txt doit '
          'contenir un entier. Génère-le avec : dart run '
          'tool/check_hardcoded_strings.dart --print',
    );
  }
  if (count > baseline) {
    return (
      exitCode: 1,
      message:
          'Textes français en dur : $count (seuil $baseline). '
          'Passe les nouveaux textes par context.l10n (lib/l10n/app_fr.arb).',
    );
  }
  if (count < baseline) {
    return (
      exitCode: 0,
      message:
          'Attention : textes français en dur : $count, sous le seuil '
          '$baseline. Abaisse tool/hardcoded_strings_baseline.txt à $count.',
    );
  }
  return (
    exitCode: 0,
    message: 'Textes français en dur : $count (seuil $baseline) OK',
  );
}

void main(List<String> args) {
  final baselineFile = File('tool/hardcoded_strings_baseline.txt');
  final count = countInLib(Directory('lib'));
  if (args.contains('--print')) {
    print(count);
    return;
  }
  final result = verdict(count, readBaseline(baselineFile));
  print(result.message);
  if (result.exitCode != 0) exit(result.exitCode);
}
