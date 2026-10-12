import 'package:dony/features/flights/data/datasources/flights_remote_datasource.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/recording_dio.dart';

const _offerJson = {
  'originCode': 'PAR',
  'destinationCode': 'ABJ',
  'originAirport': 'CDG',
  'destinationAirport': 'ABJ',
  'departureAt': '2026-12-12T11:30:00+01:00',
  'returnAt': '2027-01-08T14:05:00+00:00',
  'price': 431,
  'currency': 'EUR',
  'airlineCode': 'AT',
  'airlineName': 'Royal Air Maroc',
  'transfers': 1,
  'durationMinutes': 585,
  'gate': 'Kiwi.com',
  'offerPath': '/search/PAR1212ABJ08011',
  'logoUrl': 'https://img.test/AT.png',
};

const _paris = FlightPlace(code: 'PAR', name: 'Paris');
const _abidjan = FlightPlace(code: 'ABJ', name: 'Abidjan');

void main() {
  late RecordingApi api;
  late FlightsRemoteDatasource datasource;

  setUp(() {
    api = RecordingApi();
    datasource = FlightsRemoteDatasource(api.client);
  });

  test(
    'recherche au jour précis, aller-retour au mois, devise d\'affichage',
    () async {
      api.on('GET', '/flights/search', {
        'originCode': 'PAR',
        'destinationCode': 'ABJ',
        'roundTrip': true,
        'currency': 'XOF',
        'offers': [_offerJson],
      });

      final result = await datasource.search(
        FlightSearchQuery(
          origin: _paris,
          destination: _abidjan,
          departure: FlightWhen.day(DateTime(2026, 12, 12)),
          returnDate: FlightWhen.month(DateTime(2027, 1, 20)),
          directOnly: true,
        ),
        currency: 'XOF',
      );

      expect(api.last.queryParameters, {
        'origin': 'PAR',
        'destination': 'ABJ',
        'departureDate': '2026-12-12',
        'returnDate': '2027-01',
        'direct': true,
        'currency': 'XOF',
      });
      expect(result.roundTrip, isTrue);
      final offer = result.offers.single;
      expect(offer.departureCode, 'CDG');
      expect(offer.logoUrl, 'https://img.test/AT.png');
      // Heure locale de l'aéroport, jamais convertie au fuseau du téléphone.
      expect(offer.departureAt, DateTime(2026, 12, 12, 11, 30));
      expect(offer.isRoundTrip, isTrue);
    },
  );

  test('sans date ni devise, les paramètres sont omis', () async {
    api.on('GET', '/flights/search', {'offers': <Object>[]});

    await datasource.search(
      const FlightSearchQuery(origin: _paris, destination: _abidjan),
    );

    expect(api.last.queryParameters, {
      'origin': 'PAR',
      'destination': 'ABJ',
      'direct': false,
    });
  });

  test('clic : corps attendu par le back et lien rendu', () async {
    api.on('POST', '/flights/clicks', {
      'url': 'https://www.aviasales.com/search/X?marker=1',
    });

    final url = await datasource.click(
      FlightOffer.fromJson(_offerJson),
      source: 'deal',
    );

    expect(url, 'https://www.aviasales.com/search/X?marker=1');
    expect(api.last.data, {
      'offerPath': '/search/PAR1212ABJ08011',
      'originCode': 'PAR',
      'destinationCode': 'ABJ',
      'price': 431.0,
      'currency': 'EUR',
      'airlineCode': 'AT',
      'gate': 'Kiwi.com',
      'source': 'deal',
    });
  });

  test('alerte : périodes au jour, champs absents omis', () async {
    api.on('POST', '/me/flight-alerts', {
      'id': 'a1',
      'originCode': 'PAR',
      'destinationCode': 'ABJ',
      'departureFrom': '2026-12-12',
      'departureTo': '2026-12-31',
      'directOnly': false,
      'maxPrice': 450,
      'currency': 'EUR',
      'active': true,
    });

    final alert = await datasource.createAlert(
      FlightAlertDraft(
        originCode: 'PAR',
        destinationCode: 'ABJ',
        originLabel: 'Paris',
        departureFrom: DateTime(2026, 12, 12),
        departureTo: DateTime(2026, 12, 31),
        maxPrice: 450,
        currency: 'EUR',
      ),
    );

    expect(api.last.data, {
      'originCode': 'PAR',
      'destinationCode': 'ABJ',
      'originLabel': 'Paris',
      'departureFrom': '2026-12-12',
      'departureTo': '2026-12-31',
      'directOnly': false,
      'maxPrice': 450.0,
      'currency': 'EUR',
    });
    expect(alert.departureTo, DateTime(2026, 12, 31));
    expect(alert.isRoundTrip, isFalse);
    expect(alert.lastSeenPrice, isNull);
  });

  test('bascule d\'une alerte : PATCH avec le seul champ changé', () async {
    api.on('PATCH', '/me/flight-alerts/a1', {
      'id': 'a1',
      'originCode': 'PAR',
      'destinationCode': 'ABJ',
      'maxPrice': 450,
      'active': false,
    });

    final alert = await datasource.updateAlert('a1', active: false);

    expect(api.last.data, {'active': false});
    expect(alert.active, isFalse);
  });

  test('préremplissage : visiteur sans historique', () async {
    api.on('GET', '/flights/defaults', {'source': 'none'});

    final defaults = await datasource.defaults();

    expect(defaults.source, 'none');
    expect(defaults.origin, isNull);
  });
}
