import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _offerJson() => {
  'originCode': 'PAR',
  'destinationCode': 'ABJ',
  'departureAt': '2026-12-12T11:45:00+01:00',
  'arrivalAt': '2026-12-12T16:45:00Z',
  'price': 498,
  'currency': 'EUR',
  'airlineCode': 'SS',
  'transfers': 0,
  'outboundDurationMinutes': '360',
  'offerPath': '/search/X',
};

void main() {
  test('offre : égalité par valeur sur tous les champs', () {
    final a = FlightOffer.fromJson(_offerJson());
    final b = FlightOffer.fromJson(_offerJson());
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.props, hasLength(21));
    expect(a.outboundDurationMinutes, 360);
    expect(a, isNot(FlightOffer.fromJson({..._offerJson(), 'price': 499})));
  });

  test('résultat : égalité, chemin de recherche filtré', () {
    Map<String, dynamic> json(Object? path) => {
      'originCode': 'PAR',
      'destinationCode': 'ABJ',
      'roundTrip': true,
      'currency': 'EUR',
      'offers': [_offerJson()],
      'searchPath': path,
    };
    final a = FlightSearchResult.fromJson(json('/search/PAR1212ABJ1'));
    expect(a, FlightSearchResult.fromJson(json('/search/PAR1212ABJ1')));
    expect(a.props, hasLength(6));
    expect(FlightSearchResult.fromJson(json('/autre')).searchPath, isNull);
    expect(FlightSearchResult.fromJson(json(null)).searchPath, isNull);
    expect(FlightSearchResult.fromJson(const {}).offers, isEmpty);
  });

  test('date : jour ou mois entier', () {
    final day = FlightWhen.day(DateTime(2026, 12, 12, 9));
    expect(day.toQueryValue(), '2026-12-12');
    expect(day.first, DateTime(2026, 12, 12));
    expect(day.last, DateTime(2026, 12, 12));
    final month = FlightWhen.month(DateTime(2026, 2, 14));
    expect(month.toQueryValue(), '2026-02');
    expect(month.first, DateTime(2026, 2));
    expect(month.last, DateTime(2026, 2, 28));
    expect(month, FlightWhen.month(DateTime(2026, 2, 3)));
    expect(month, isNot(day));
  });

  test('durée de l\'aller : jamais le total d\'un aller-retour', () {
    Map<String, dynamic> rt(Map<String, dynamic> extra) => {
      ..._offerJson(),
      'outboundDurationMinutes': null,
      'returnAt': '2027-01-03T23:30:00Z',
      ...extra,
    };
    // Aller simple, ancien back : le total est l'aller.
    expect(
      FlightOffer.fromJson({
        ..._offerJson(),
        'outboundDurationMinutes': null,
        'durationMinutes': 365,
      }).outboundMinutes,
      365,
    );
    // Aller-retour : total seul, rien ; total et retour, la différence.
    expect(
      FlightOffer.fromJson(rt({'durationMinutes': 740})).outboundMinutes,
      isNull,
    );
    expect(
      FlightOffer.fromJson(
        rt({'durationMinutes': 740, 'returnDurationMinutes': 380}),
      ).outboundMinutes,
      360,
    );
    expect(
      FlightOffer.fromJson(
        rt({'durationMinutes': 300, 'returnDurationMinutes': 380}),
      ).outboundMinutes,
      isNull,
    );
  });
}
