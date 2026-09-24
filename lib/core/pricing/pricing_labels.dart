import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Libellé du taux de commission Yadony courant ([donyCommissionRate]),
/// entier sans décimale si le taux est rond, sinon une décimale à la langue
/// (fr `12,5`, en `12.5`). Sans le symbole `%` : à interpoler dans une clé ARB
/// portant déjà la ponctuation propre à chaque langue (espace en français,
/// aucune en anglais).
String commissionPercentLabel(AppLocalizations l) {
  final pct = donyCommissionRate * 100;
  return pct % 1 == 0 ? pct.toStringAsFixed(0) : formatOneDecimal(l, pct);
}

/// Libellé du plafond de remboursement Yadony courant
/// ([donyReimbursementCapEur]), entier sans décimale si le montant est rond,
/// sinon deux décimales au plus sans zéro final, à la langue.
String reimbursementCapLabel(AppLocalizations l) {
  final v = donyReimbursementCapEur;
  if (v % 1 == 0) return v.toStringAsFixed(0);
  final trimmed = v
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  final decimalIndex = trimmed.indexOf('.');
  if (decimalIndex < 0) return trimmed;
  final integerPart = trimmed.substring(0, decimalIndex);
  final decimalPart = trimmed.substring(decimalIndex + 1);
  // Séparateur décimal de la locale (au lieu d'un choix fr/en codé en dur) :
  // une langue ajoutée plus tard n'a pas besoin de toucher cette fonction.
  final separator = NumberFormat.decimalPattern(
    l.localeName,
  ).symbols.DECIMAL_SEP;
  return '$integerPart$separator$decimalPart';
}
