import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

/// Mises en forme partagées par les écrans de billets.
abstract final class FlightFormat {
  /// « 431 € », « 250 000 F CFA » ; une devise hors catalogue (MAD) garde son
  /// code ISO après le montant.
  static String price(double amount, String currencyCode) {
    final currency = SupportedCurrency.fromCode(currencyCode);
    if (currency != null) {
      return CurrencyFormatter.format(amount, currency, compact: true);
    }
    return '${NumberFormat.decimalPattern().format(amount.round())} $currencyCode';
  }

  /// « 9 h 45 », « 6 h ».
  static String duration(AppLocalizations l, int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0
        ? l.flightsDurationHours(h)
        : l.flightsDurationHoursMinutes(h, m);
  }

  /// « Direct », « 1 escale », « 2 escales » ; `null` si inconnu.
  static String? stops(AppLocalizations l, int? transfers) {
    if (transfers == null) return null;
    return transfers == 0
        ? l.flightsStopsDirect
        : l.flightsStopsCount(transfers);
  }

  /// « 1 escale · 9 h 45 » : ce qui est connu, séparé par un point médian.
  static String stopsAndDuration(AppLocalizations l, FlightOffer o) => [
    ?stops(l, o.transfers),
    if (o.durationMinutes != null) duration(l, o.durationMinutes!),
  ].join(' · ');

  /// « sam. 12 déc. · 11:30 », l'heure omise si le partenaire ne la donne pas.
  static String dateTime(
    AppLocalizations l,
    DateTime d, {
    bool withTime = true,
  }) {
    final date = DateFormat.MMMEd(l.localeName).format(d);
    final hasTime = d.hour != 0 || d.minute != 0;
    return withTime && hasTime
        ? '$date · ${DateFormat.Hm(l.localeName).format(d)}'
        : date;
  }

  /// « 12 déc. 2026 ».
  static String day(AppLocalizations l, DateTime d) =>
      DateFormat.yMMMd(l.localeName).format(d);

  /// « décembre 2026 ».
  static String month(AppLocalizations l, DateTime d) =>
      DateFormat.yMMMM(l.localeName).format(d);
}
