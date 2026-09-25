import 'dart:math';

// Table de repliement des diacritiques latins vers leur lettre de base :
// donnée de calcul (jamais affichée), pas du texte à traduire.
const _accents = {
  'à': 'a', // i18n-ignore
  'â': 'a', // i18n-ignore
  'ä': 'a', // i18n-ignore
  'á': 'a',
  'é': 'e', // i18n-ignore
  'è': 'e', // i18n-ignore
  'ê': 'e', // i18n-ignore
  'ë': 'e', // i18n-ignore
  'î': 'i', // i18n-ignore
  'ï': 'i', // i18n-ignore
  'í': 'i',
  'ô': 'o', // i18n-ignore
  'ö': 'o', // i18n-ignore
  'ó': 'o',
  'ù': 'u', // i18n-ignore
  'û': 'u', // i18n-ignore
  'ü': 'u', // i18n-ignore
  'ú': 'u',
  'ÿ': 'y', // i18n-ignore
  'ç': 'c', // i18n-ignore
  'ñ': 'n',
};
final _letter = RegExp('[a-z]');

/// Code à 3 lettres affiché sur le billet. Pas un code IATA : Divo n'a pas d'aéroport.
String cityCode(String city) {
  final name = city.split(RegExp('[·,(]')).first.trim().toLowerCase();
  final letters = name
      .split('')
      .map((c) => _accents[c] ?? c)
      .where(_letter.hasMatch)
      .join();
  if (letters.isEmpty) return '···';
  return letters.substring(0, min(3, letters.length)).toUpperCase();
}
