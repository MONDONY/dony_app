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

/// Valeur seule d'un poids, sans unité, à la langue [localeName] : deux
/// décimales au plus, aucune quand le poids est entier (« 0,5 », « 0,25 »,
/// « 3 » en français). Pour les surfaces qui posent « kg » à part (gros
/// chiffre du formulaire de demande, champ de saisie).
String formatWeightValue(String localeName, double kg) =>
    NumberFormat('#0.##', localeName).format(kg);
