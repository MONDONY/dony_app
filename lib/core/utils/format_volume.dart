import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Volume en mètres cubes à la langue de [l] : milliers groupés, une
/// décimale au plus, aucune quand le volume est entier (« 12,5 m³ »,
/// « 1 200 m³ » en français, « 12.5 m³ » en anglais).
String formatVolumeM3(AppLocalizations l, double m3) =>
    '${NumberFormat('#,##0.#', l.localeName).format(m3)} m³';

/// Volume ENCORE DISPONIBLE d'un trajet bateau (« 0,4 m³ », « 0,35 m³ ») :
/// arrondi vers le bas à deux décimales, jamais vers le haut. Le serveur tient
/// le volume restant à trois décimales ; l'arrondir au plus proche afficherait
/// 0,4 m³ pour 0,35 m³ et laisserait croire qu'un colis de 0,4 m³ passe.
String formatVolumeRemainingM3(AppLocalizations l, double m3) {
  final floored = (m3 * 100).floorToDouble() / 100;
  return '${NumberFormat('#,##0.##', l.localeName).format(floored)} m³';
}

/// Valeur seule d'un volume, sans unité ni séparateur de milliers, pour un
/// champ de saisie (« 12,5 » en français).
String formatVolumeValue(String localeName, double m3) =>
    NumberFormat('#0.#', localeName).format(m3);

/// Volume saisi (virgule ou point), `null` si vide ou illisible.
double? readVolumeInput(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

/// Volume d'un colis (« 0,10 m³ », « 0,024 m³ ») : deux décimales au moins,
/// trois au plus, comme le serveur le calcule. Distinct de [formatVolumeM3],
/// qui sert aux capacités d'un trajet, à une décimale.
String formatParcelVolumeM3(AppLocalizations l, double m3) =>
    '${NumberFormat('0.00#', l.localeName).format(m3)} m³';
