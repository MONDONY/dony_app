import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Volume en mètres cubes à la langue de [l] : milliers groupés, une
/// décimale au plus, aucune quand le volume est entier (« 12,5 m³ »,
/// « 1 200 m³ » en français, « 12.5 m³ » en anglais).
String formatVolumeM3(AppLocalizations l, double m3) =>
    '${NumberFormat('#,##0.#', l.localeName).format(m3)} m³';

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
