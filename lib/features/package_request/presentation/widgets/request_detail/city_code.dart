import 'dart:math';

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ô': 'o', 'ö': 'o', 'ó': 'o', 'ù': 'u', 'û': 'u',
  'ü': 'u', 'ú': 'u', 'ÿ': 'y', 'ç': 'c', 'ñ': 'n',
};
final _letter = RegExp('[a-z]');

/// Code à 3 lettres affiché sur le billet. Pas un code IATA : Divo n'a pas d'aéroport.
String cityCode(String city) {
  final name = city.split(RegExp('[·,(]')).first.trim().toLowerCase();
  final letters = name.split('').map((c) => _accents[c] ?? c).where(_letter.hasMatch).join();
  if (letters.isEmpty) return '···';
  return letters.substring(0, min(3, letters.length)).toUpperCase();
}
