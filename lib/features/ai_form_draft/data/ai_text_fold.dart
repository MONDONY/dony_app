/// Lettres accentuées et leur forme simple, à la même position.
const _accented =
    'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ'; // i18n-ignore : table de translittération
const _plain = 'aaaaaaceeeeiiiinooooouuuuyy';
// Table de translittération, pas un texte affiché.
const _ligatures = {
  'œ': 'oe', // i18n-ignore
  'æ': 'ae', // i18n-ignore
};

final _separators = RegExp(r"[\s\-'’]+");

/// Forme de comparaison d'un libellé dit ou écrit par l'utilisateur :
/// minuscules, sans accents, tirets, apostrophes et espaces réduits à une
/// espace. « Vêtements » et « vetements », « Saint-Louis » et « saint louis »
/// se comparent égaux.
String foldForMatch(String input) {
  final buffer = StringBuffer();
  for (final rune in input.trim().toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = _accented.indexOf(char);
    if (index != -1) {
      buffer.write(_plain[index]);
    } else {
      buffer.write(_ligatures[char] ?? char);
    }
  }
  return buffer.toString().replaceAll(_separators, ' ').trim();
}
