import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Formatage d'un poids en kilogrammes pour l'affichage, à la langue
/// courante (virgule en français, point en anglais ; entier sans décimale).
///
/// L'expression `toStringAsFixed(w.truncateToDouble() == w ? 0 : 1)` était
/// recopiée dans chaque surface qui affiche un poids, et les copies avaient
/// déjà divergé sur le séparateur décimal : le même colis se lisait « 4.5 kg »
/// à un endroit et « 4,5 kg » à un autre. `replaceFirst('.', ',')` figeait en
/// plus la virgule quelle que soit la langue effective.
String formatWeightKg(AppLocalizations l, double kg) =>
    '${NumberFormat('#0.#', l.localeName).format(kg)} kg';
