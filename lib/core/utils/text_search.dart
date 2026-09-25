// Table de repliement des diacritiques latins vers leur lettre de base :
// donnée de recherche (jamais affichée), pas du texte à traduire.
const _diacriticsMap = {
  'à': 'a', // i18n-ignore
  'â': 'a', // i18n-ignore
  'ä': 'a', // i18n-ignore
  'á': 'a',
  'ã': 'a',
  'å': 'a',
  'ç': 'c', // i18n-ignore
  'é': 'e', // i18n-ignore
  'è': 'e', // i18n-ignore
  'ê': 'e', // i18n-ignore
  'ë': 'e', // i18n-ignore
  'î': 'i', // i18n-ignore
  'ï': 'i', // i18n-ignore
  'í': 'i',
  'ì': 'i',
  'ô': 'o', // i18n-ignore
  'ö': 'o', // i18n-ignore
  'ó': 'o',
  'ò': 'o',
  'õ': 'o',
  'ù': 'u', // i18n-ignore
  'û': 'u', // i18n-ignore
  'ü': 'u', // i18n-ignore
  'ú': 'u',
  'ñ': 'n',
  'ÿ': 'y', // i18n-ignore
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
