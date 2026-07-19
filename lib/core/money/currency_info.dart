/// Donnée de référence pour une devise, synchronisée depuis
/// `GET /config/currencies` (voir [CurrencyRegistry]).
///
/// Purement descriptif : ne sert jamais à calculer un montant transactionnel
/// côté client (règle R1 du spec devise) — uniquement à l'affichage.
class CurrencyInfo {
  const CurrencyInfo({
    required this.code,
    required this.minorUnit,
    required this.symbol,
    this.pegRateToEur,
    this.roundingIncrement = 1,
  });

  /// Code ISO 4217 (ex. `EUR`, `XOF`, `XAF`).
  final String code;

  /// Nombre de décimales de l'unité mineure (0 pour XOF/XAF, 2 pour EUR).
  final int minorUnit;

  /// Symbole d'affichage (ex. `€`, `F CFA`).
  final String symbol;

  /// Parité fixe vers l'EUR, si connue. `null` = flottante ou inconnue →
  /// jamais d'équivalent local inventé (voir [formatDual] dans
  /// `money_formatter.dart`).
  final double? pegRateToEur;

  /// Incrément d'arrondi indicatif de la devise (ex. 5 pour XOF/XAF).
  final int roundingIncrement;

  factory CurrencyInfo.fromJson(Map<String, dynamic> json) => CurrencyInfo(
        code: json['code'] as String,
        minorUnit: (json['minorUnit'] as num).toInt(),
        symbol: json['symbol'] as String,
        pegRateToEur: (json['pegRateToEur'] as num?)?.toDouble(),
        roundingIncrement: (json['roundingIncrement'] as num?)?.toInt() ?? 1,
      );
}
