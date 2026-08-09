import 'package:dony/core/currency/supported_currency.dart';
import 'package:intl/intl.dart';

abstract final class CurrencyFormatter {
  static String format(
    num amount,
    SupportedCurrency currency, {
    String? locale,
  }) {
    final formatter = NumberFormat.currency(
      locale: locale ?? currency.locale,
      name: currency.code,
      symbol: currency.symbol,
      decimalDigits: currency.minorUnit,
    );
    return formatter.format(amount);
  }
}
