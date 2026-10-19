import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/commission_pricing.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

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

/// Message d'un prix au kilo hors des bornes de [currency] (FLUTTER-GK),
/// montant formaté dans cette devise, ou `null` si [price] les respecte ou
/// n'est pas saisi.
String? unitPriceBoundsError(
  AppLocalizations l,
  double? price,
  SupportedCurrency currency,
) => switch (unitPriceOutOfBounds(price, currency)) {
  UnitPriceBound.tooLow => l.pricePerKgTooLow(
    CurrencyFormatter.format(
      minUnitPriceFor(currency),
      currency,
      compact: true,
    ),
  ),
  UnitPriceBound.tooHigh => l.pricePerKgTooHigh(
    CurrencyFormatter.format(
      maxUnitPriceFor(currency),
      currency,
      compact: true,
    ),
  ),
  null => null,
};

/// Prix d'un trajet tarifé à la grille sur une carte compacte (FLUTTER-PC) :
/// « dès 15 € » quand le serveur sert le prix le plus bas de la grille
/// ([minGridUnitPriceDisplay], net + commission, dans [currency]), sinon
/// « Grille tarifaire ». Jamais « 0 € /kg ».
String gridPriceLabel(
  AppLocalizations l,
  double? minGridUnitPriceDisplay,
  String? currency,
) {
  final min = minGridUnitPriceDisplay;
  return min != null && min > 0
      ? l.tripPosterFromPrice(formatPriceIn(min, currency))
      : l.listingPriceGridLabel;
}

/// Mention « + frais de service Yadony (min. 1 €) » à poser sous un prix au
/// kilo affiché au net, `null` sans grille de commission en vigueur (ou sans
/// minimum pour [currencyCode]) : l'affichage reste alors celui du taux unique.
///
/// Le minimum est formaté dans [currencyCode], la devise du prix qu'elle
/// accompagne. Avec [withMinimum] à `false` (carte des trajets, faute de
/// place), la mention se limite à « + frais de service ».
String? listPriceFeeSuffix(
  AppLocalizations l,
  String? currencyCode, {
  bool withMinimum = true,
}) {
  final minimum = commissionMinimumFor(currencyCode);
  if (minimum == null) return null;
  return withMinimum
      ? l.listPriceServiceFeeSuffix(formatPriceIn(minimum, currencyCode))
      : l.listPriceServiceFeeShortSuffix;
}

/// Montant de frais de service avec ses décimales, suivi de « (minimum) »
/// quand [minimum] indique que le plancher de la grille s'applique.
String serviceFeeAmountLabel(
  AppLocalizations l,
  double amount,
  String? currencyCode, {
  required bool minimum,
}) {
  final money = CurrencyFormatter.format(
    amount,
    SupportedCurrency.fromCodeOrDefault(currencyCode),
  );
  return minimum ? '$money\u00A0${l.serviceFeeMinimumTag}' : money;
}
