const _diacriticsMap = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ñ': 'n',
  'ÿ': 'y',
};

/// Minuscule + suppression des diacritiques.
/// Préserve la longueur (1 char → 1 char) — les index sur la chaîne normalisée
/// restent valides sur la chaîne d'origine (utilisé pour le surlignage).
String normalizeSearch(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    buffer.write(_diacriticsMap[ch] ?? ch);
  }
  return buffer.toString();
}
