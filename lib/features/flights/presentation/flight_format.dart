import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/l10n/country_names.dart';
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

  /// « 9 h 45 », « 6 h 05 », « 6 h ».
  static String duration(AppLocalizations l, int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0
        ? l.flightsDurationHours(h)
        : l.flightsDurationHoursMinutes(h, m.toString().padLeft(2, '0'));
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

  /// « 06:10 », `null` si le partenaire ne donne que la date (minuit pile).
  static String? time(AppLocalizations l, DateTime? d) {
    if (d == null || (d.hour == 0 && d.minute == 0)) return null;
    return DateFormat.Hm(l.localeName).format(d);
  }

  /// « 12 déc. ».
  static String dayMonth(AppLocalizations l, DateTime d) =>
      DateFormat.MMMd(l.localeName).format(d);

  /// « décembre » (nom du mois seul).
  static String monthName(AppLocalizations l, DateTime d) =>
      DateFormat.MMMM(l.localeName).format(d);

  /// Valeur d'un champ date du formulaire : « sam. 12 déc. », « décembre
  /// 2026 », ou « Toutes les dates ».
  static String when(AppLocalizations l, FlightWhen? w) => w == null
      ? l.flightsDatesAny
      : w.wholeMonth
      ? month(l, w.date)
      : DateFormat.MMMEd(l.localeName).format(w.date);

  /// Dates courtes d'une recherche : « 12 déc. – 3 janv. », « mars 2027 »,
  /// « 12 déc. », ou « Toutes les dates ».
  static String dates(AppLocalizations l, FlightWhen? out, FlightWhen? back) {
    String one(FlightWhen w) =>
        w.wholeMonth ? month(l, w.date) : dayMonth(l, w.date);
    if (out == null) return l.flightsDatesAny;
    if (back == null) return one(out);
    if (out.wholeMonth && back.wholeMonth && out == back) return one(out);
    return l.flightsDateRange(one(out), one(back));
  }

  /// « Paris ⇄ Abidjan » en aller-retour, « Paris → Abidjan » sinon.
  static String route(
    AppLocalizations l,
    String origin,
    String destination, {
    required bool roundTrip,
  }) => roundTrip
      ? l.flightsRouteRoundTrip(origin, destination)
      : l.flightsRouteTitle(origin, destination);

  /// Pays affiché d'une ville : le nom donné par le back, sinon celui du
  /// catalogue de l'app ; `null` si inconnu.
  static String? country(AppLocalizations l, FlightPlace place) {
    final name = place.countryName;
    if (name != null && name.isNotEmpty) return name;
    final code = place.countryCode;
    if (code == null || code.isEmpty) return null;
    final known = countryName(l, code.toUpperCase());
    return known == code.toUpperCase() ? null : known;
  }

  /// « Paris, France », ou le nom seul.
  static String placeName(AppLocalizations l, FlightPlace place) {
    final c = country(l, place);
    return c == null ? place.name : '${place.name}, $c';
  }

  /// Drapeau emoji d'un code pays ISO 3166-1 alpha-2, `null` si le code
  /// n'en est pas un.
  static String? flag(String? countryCode) {
    final code = countryCode?.toUpperCase();
    if (code == null || !RegExp(r'^[A-Z]{2}$').hasMatch(code)) return null;
    return String.fromCharCodes(code.codeUnits.map((c) => 0x1F1E6 + c - 65));
  }

  /// Ancienneté d'une recherche : « à l'instant », « il y a 2 j »…
  static String age(AppLocalizations l, DateTime at, DateTime now) {
    final d = now.difference(at);
    if (d.inMinutes < 1) return l.flightsAgoNow;
    if (d.inHours < 1) return l.flightsAgoMinutes(d.inMinutes);
    if (d.inDays < 1) return l.flightsAgoHours(d.inHours);
    if (d.inDays < 7) return l.flightsAgoDays(d.inDays);
    return l.flightsAgoWeeks(d.inDays ~/ 7);
  }
}
