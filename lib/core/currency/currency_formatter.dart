import 'package:dony/core/currency/supported_currency.dart';
import 'package:intl/intl.dart';

abstract final class CurrencyFormatter {
  /// `NumberFormat` est coûteux à construire (résolution de locale + parsing du
  /// pattern) et ce formateur est sur le chemin de tous les prix affichés,
  /// `itemBuilder` de listes compris. L'espace de clés est borné par le
  /// catalogue (7 devises × 2 précisions), donc le cache ne croît pas.
  static final Map<String, NumberFormat> _cache = {};

  static final NumberFormat _plainFormatter = NumberFormat.decimalPattern(
    'fr_FR',
  );

  static NumberFormat _formatterFor(
    String locale,
    String code,
    String symbol,
    int decimalDigits,
  ) {
    return _cache.putIfAbsent(
      '$locale|$code|$symbol|$decimalDigits',
      () => NumberFormat.currency(
        locale: locale,
        name: code,
        symbol: symbol,
        decimalDigits: decimalDigits,
      ),
    );
  }

  static String format(
    num amount,
    SupportedCurrency currency, {
    String? locale,
    bool compact = false,
  }) {
    final isWhole = amount == amount.truncateToDouble();
    return _formatterFor(
      locale ?? currency.locale,
      currency.code,
      currency.symbol,
      compact && isWhole ? 0 : currency.minorUnit,
    ).format(amount);
  }

  /// Formate le montant seul, sans symbole, mais avec le nombre de décimales de
  /// la devise. Réservé aux surfaces qui affichent déjà le code devise à côté du
  /// montant : un `decimalDigits` figé à 2 rendrait « 1 500,00 » en XOF, qui n'a
  /// pas de sous-unité.
  static String formatAmountOnly(num amount, SupportedCurrency currency) =>
      _formatterFor(
        currency.locale,
        currency.code,
        '',
        currency.minorUnit,
      ).format(amount).trim();

  /// Formate un montant avec la devise active, sans inventer de devise quand
  /// sa synchronisation n'a pas encore abouti.
  static String formatOrPlain(
    num amount,
    SupportedCurrency? currency, {
    bool compact = false,
  }) {
    if (currency == null) {
      return _plainFormatter.format(amount);
    }
    return format(amount, currency, compact: compact);
  }
}
