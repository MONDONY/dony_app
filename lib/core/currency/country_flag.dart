/// Drapeau emoji d'un pays à partir de son code ISO 3166-1 alpha-2.
///
/// Chaque lettre devient l'indicateur régional Unicode correspondant
/// (`A` → U+1F1E6) : la paire forme le drapeau, pour n'importe quel pays,
/// dans le catalogue ou hors catalogue (ex. `GN`, renvoyé par la recherche
/// d'adresse ou déjà enregistré). Un code vide ou mal formé rend `null` :
/// l'appelant affiche alors une icône neutre au lieu de planter.
String? countryFlagEmoji(String? code) {
  if (code == null) {
    return null;
  }
  final normalized = code.trim().toUpperCase();
  if (normalized.length != 2) {
    return null;
  }
  const a = 0x41;
  const z = 0x5A;
  const regionalIndicatorA = 0x1F1E6;
  final units = normalized.codeUnits;
  if (units.any((u) => u < a || u > z)) {
    return null;
  }
  return String.fromCharCodes(units.map((u) => regionalIndicatorA + u - a));
}
