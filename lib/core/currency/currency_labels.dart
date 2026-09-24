import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/l10n/l10n.dart';

/// Nom affichable d'une [SupportedCurrency], à la langue courante.
///
/// Remplace l'ancien champ `SupportedCurrency.displayName` (toujours en
/// français) : le code et le symbole restent invariants, seul le nom complet
/// suit la langue de l'app.
extension SupportedCurrencyL10n on SupportedCurrency {
  String name(AppLocalizations l) {
    switch (code) {
      case 'EUR':
        return l.currencyNameEur;
      case 'USD':
        return l.currencyNameUsd;
      case 'CAD':
        return l.currencyNameCad;
      case 'GBP':
        return l.currencyNameGbp;
      case 'CHF':
        return l.currencyNameChf;
      case 'XOF':
        return l.currencyNameXof;
      case 'XAF':
        return l.currencyNameXaf;
      default:
        return code;
    }
  }
}
