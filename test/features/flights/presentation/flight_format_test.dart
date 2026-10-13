import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late AppLocalizations fr;
  late AppLocalizations en;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    fr = await AppLocalizations.delegate.load(AppL10n.fr);
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('durées : minutes sur deux chiffres', () {
    expect(FlightFormat.duration(fr, 365), '6 h 05');
    expect(FlightFormat.duration(fr, 360), '6 h');
    expect(FlightFormat.duration(en, 635), '10h 35m');
  });

  test('heure locale, inconnue à minuit pile', () {
    expect(FlightFormat.time(fr, DateTime(2026, 12, 12, 6, 10)), '06:10');
    expect(FlightFormat.time(fr, DateTime(2026, 12, 12)), isNull);
    expect(FlightFormat.time(fr, null), isNull);
  });

  test('dates d\'une recherche', () {
    final out = FlightWhen.day(DateTime(2026, 12, 12));
    final back = FlightWhen.day(DateTime(2027, 1, 3));
    expect(FlightFormat.dates(fr, out, back), '12 déc. – 3 janv.');
    expect(FlightFormat.dates(fr, out, null), '12 déc.');
    expect(
      FlightFormat.dates(fr, FlightWhen.month(DateTime(2027, 3)), null),
      'mars 2027',
    );
    final march = FlightWhen.month(DateTime(2027, 3));
    expect(FlightFormat.dates(fr, march, march), 'mars 2027');
    expect(FlightFormat.dates(fr, null, null), 'Toutes les dates');
    expect(FlightFormat.when(fr, out), 'sam. 12 déc.');
    expect(FlightFormat.when(fr, null), 'Toutes les dates');
    expect(FlightFormat.monthName(fr, DateTime(2026, 10)), 'octobre');
  });

  group('dates d\'une alerte', () {
    FlightAlert alert({
      DateTime? departureFrom,
      DateTime? departureTo,
      DateTime? returnFrom,
      DateTime? returnTo,
    }) => FlightAlert(
      id: 'a1',
      originCode: 'PAR',
      destinationCode: 'DKR',
      departureFrom: departureFrom,
      departureTo: departureTo,
      returnFrom: returnFrom,
      returnTo: returnTo,
      directOnly: false,
      maxPrice: 450,
      currency: 'EUR',
      active: true,
    );

    test('jour unique, aller-retour', () {
      final a = alert(
        departureFrom: DateTime(2026, 12, 23),
        departureTo: DateTime(2026, 12, 23, 12),
        returnFrom: DateTime(2027, 1, 2),
        returnTo: DateTime(2027, 1, 2),
      );
      expect(FlightFormat.alertDates(fr, a), [
        'Départ le 23 déc. 2026',
        'Retour le 2 janv. 2027',
      ]);
      expect(FlightFormat.alertDates(en, a), [
        'Departure Dec 23, 2026',
        'Return Jan 2, 2027',
      ]);
    });

    test('période dans la même année : année non répétée', () {
      final a = alert(
        departureFrom: DateTime(2026, 12),
        departureTo: DateTime(2026, 12, 20),
        returnFrom: DateTime(2027, 1, 2),
        returnTo: DateTime(2027, 1, 15),
      );
      expect(FlightFormat.alertDates(fr, a), [
        'Départ du 1 déc. au 20 déc. 2026',
        'Retour du 2 janv. au 15 janv. 2027',
      ]);
      expect(FlightFormat.alertDates(en, a), [
        'Departure Dec 1 to Dec 20, 2026',
        'Return Jan 2 to Jan 15, 2027',
      ]);
    });

    test('période à cheval sur deux années : les deux années', () {
      final a = alert(
        departureFrom: DateTime(2026, 12, 28),
        departureTo: DateTime(2027, 1, 3),
      );
      expect(FlightFormat.alertDates(fr, a), [
        'Départ du 28 déc. 2026 au 3 janv. 2027',
        'Aller simple',
      ]);
      expect(FlightFormat.alertDates(en, a), [
        'Departure Dec 28, 2026 to Jan 3, 2027',
        'One way',
      ]);
    });

    test('sans période', () {
      expect(FlightFormat.alertDates(fr, alert()), [
        'Départ à toutes dates',
        'Aller simple',
      ]);
      expect(FlightFormat.alertDates(en, alert())[0], 'Any departure date');
      expect(
        FlightFormat.alertReturn(fr, DateTime(2027, 1, 2), null),
        'Retour à toutes dates',
      );
      expect(FlightFormat.alertReturn(en, null, null), 'Any return date');
    });
  });

  test('trajet aller-retour ou aller simple', () {
    expect(
      FlightFormat.route(fr, 'Paris', 'Abidjan', roundTrip: true),
      'Paris ↔ Abidjan',
    );
    expect(
      FlightFormat.route(fr, 'Paris', 'Abidjan', roundTrip: false),
      'Paris → Abidjan',
    );
  });

  test('pays : nom du back, sinon catalogue, sinon rien', () {
    expect(
      FlightFormat.country(
        fr,
        const FlightPlace(code: 'X', name: 'X', countryName: 'Mali'),
      ),
      'Mali',
    );
    expect(
      FlightFormat.placeName(
        fr,
        const FlightPlace(code: 'CMN', name: 'Casablanca', countryCode: 'ma'),
      ),
      'Casablanca, Maroc',
    );
    expect(
      FlightFormat.placeName(
        fr,
        const FlightPlace(code: 'NBO', name: 'Nairobi', countryCode: 'KE'),
      ),
      'Nairobi',
    );
    expect(
      FlightFormat.country(fr, const FlightPlace(code: 'X', name: 'X')),
      isNull,
    );
  });

  test('drapeau emoji du code pays', () {
    expect(FlightFormat.flag('CI'), '🇨🇮');
    expect(FlightFormat.flag('sn'), '🇸🇳');
    expect(FlightFormat.flag('FRA'), isNull);
    expect(FlightFormat.flag(null), isNull);
  });

  test('ancienneté d\'une recherche', () {
    final now = DateTime(2026, 10, 12, 12);
    expect(FlightFormat.age(fr, now, now), 'à l\'instant');
    expect(
      FlightFormat.age(fr, now.subtract(const Duration(minutes: 5)), now),
      'il y a 5 min',
    );
    expect(
      FlightFormat.age(fr, now.subtract(const Duration(hours: 3)), now),
      'il y a 3 h',
    );
    expect(
      FlightFormat.age(fr, now.subtract(const Duration(days: 2)), now),
      'il y a 2 j',
    );
    expect(
      FlightFormat.age(fr, now.subtract(const Duration(days: 15)), now),
      'il y a 2 sem.',
    );
    expect(
      FlightFormat.age(en, now.subtract(const Duration(days: 2)), now),
      '2 d ago',
    );
  });
}
