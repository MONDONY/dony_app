import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Marge, en centièmes de m³, qui absorbe la dérive des flottants avant un
/// arrondi (`8.2 * 100` vaut 819,99999999999994).
const double _floatSlack = 1e-9;

/// Volume en mètres cubes à la langue de [l] : milliers groupés, une
/// décimale au plus, aucune quand le volume est entier (« 12,5 m³ »,
/// « 1 200 m³ » en français, « 12.5 m³ » en anglais).
String formatVolumeM3(AppLocalizations l, double m3) =>
    '${NumberFormat('#,##0.#', l.localeName).format(m3)} m³';

/// Volume ENCORE DISPONIBLE d'un trajet bateau (« 0,4 m³ », « 0,35 m³ ») :
/// arrondi vers le bas à deux décimales, jamais vers le haut. Le serveur tient
/// le volume restant à trois décimales ; l'arrondir au plus proche afficherait
/// 0,4 m³ pour 0,35 m³ et laisserait croire qu'un colis de 0,4 m³ passe.
///
/// Une petite marge corrige la dérive des flottants : `(8.2 * 100).floor()`
/// vaut 819 et afficherait 8,19 m³ pour 8,2 m³. Elle est bien inférieure au
/// millième, la précision du serveur : 0,399 reste 0,39.
String formatVolumeRemainingM3(AppLocalizations l, double m3) {
  final floored = ((m3 * 100) + _floatSlack).floor() / 100;
  return '${NumberFormat('#,##0.##', l.localeName).format(floored)} m³';
}

/// Volume DÉJÀ VENDU d'un trajet bateau, à côté de [formatVolumeRemainingM3] :
/// même nombre de décimales (deux au plus), arrondi vers le HAUT pour que le
/// vendu et le restant (arrondi vers le bas) s'additionnent à la capacité.
String formatVolumeSoldM3(AppLocalizations l, double m3) {
  final ceiled = ((m3 * 100) - _floatSlack).ceil() / 100;
  return '${NumberFormat('#,##0.##', l.localeName).format(ceiled)} m³';
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
