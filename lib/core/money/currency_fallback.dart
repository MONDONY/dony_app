import 'package:dony/core/money/currency_info.dart';

/// Filet offline INDICATIF uniquement (règle R1 du spec devise : le client ne
/// calcule jamais un montant transactionnel — celui-ci arrive toujours du
/// serveur en unités mineures). Utilisé par [CurrencyRegistry] tant que la
/// synchro `GET /config/currencies` n'a pas eu lieu, ou si elle échoue.
///
/// Parité CFA fixe vérifiée 2026-07-18 (BCEAO / BEAC, XOF et XAF partagent la
/// même parité EUR).
const List<CurrencyInfo> kFallbackCurrencies = [
  CurrencyInfo(code: 'EUR', minorUnit: 2, symbol: '€'),
  CurrencyInfo(
    code: 'XOF',
    minorUnit: 0,
    symbol: 'F CFA',
    pegRateToEur: 655.957,
    roundingIncrement: 5,
  ),
  CurrencyInfo(
    code: 'XAF',
    minorUnit: 0,
    symbol: 'F CFA',
    pegRateToEur: 655.957,
    roundingIncrement: 5,
  ),
];
