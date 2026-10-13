import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/data/models/flight_alert_offers.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:flutter_test/flutter_test.dart';

const _base = {
  'id': 'a1',
  'originCode': 'PAR',
  'destinationCode': 'ABJ',
  'maxPrice': 450,
  'currency': 'EUR',
  'active': true,
};

FlightAlert _alert({
  DateTime? from,
  DateTime? to,
  DateTime? returnFrom,
  DateTime? returnTo,
  double? seen,
  int? count,
}) => FlightAlert(
  id: 'a1',
  originCode: 'PAR',
  destinationCode: 'ABJ',
  departureFrom: from,
  departureTo: to,
  returnFrom: returnFrom,
  returnTo: returnTo,
  directOnly: false,
  maxPrice: 450,
  currency: 'EUR',
  active: true,
  lastSeenPrice: seen,
  matchCount: count,
);

void main() {
  group('FlightAlert : résultat de la dernière vérification', () {
    test('back récent : nombre de vols et compagnies (trois au plus)', () {
      final alert = FlightAlert.fromJson(const {
        ..._base,
        'lastSeenPrice': 389,
        'lastCheckedAt': '2026-10-13T06:00:00Z',
        'matchCount': 3,
        'matchAirlineCodes': ['AT', ' SS ', '', 7, 'AF', 'TK'],
      });

      expect(alert.matchCount, 3);
      expect(alert.matchAirlineCodes, ['AT', 'SS', 'AF']);
      expect(alert.hasHit, isTrue);
      expect(alert.checked, isTrue);
    });

    test('ancien back : champs absents, le dernier prix vu décide', () {
      final under = FlightAlert.fromJson(const {
        ..._base,
        'lastSeenPrice': 450,
      });
      final over = FlightAlert.fromJson(const {..._base, 'lastSeenPrice': 451});
      final never = FlightAlert.fromJson(_base);

      expect(under.matchCount, isNull);
      expect(under.matchAirlineCodes, isEmpty);
      expect(under.hasHit, isTrue);
      expect(over.hasHit, isFalse);
      expect(never.hasHit, isFalse);
      expect(never.checked, isFalse);
    });

    test('matchCount à 0 l\'emporte sur un dernier prix sous le seuil', () {
      expect(_alert(seen: 300, count: 0).hasHit, isFalse);
      // Prix périmé : plus montré comme meilleur prix du moment.
      expect(_alert(seen: 300, count: 0).currentPrice, isNull);
      expect(_alert(seen: 500, count: 0).currentPrice, 500);
      expect(_alert(seen: 300).currentPrice, 300);
      expect(_alert().currentPrice, isNull);
    });

    test('copyWith garde le résultat ; égalité sur les nouveaux champs', () {
      final alert = FlightAlert.fromJson(const {
        ..._base,
        'matchCount': 2,
        'matchAirlineCodes': ['AT'],
      });
      final paused = alert.copyWith(active: false);

      expect(paused.matchCount, 2);
      expect(paused.matchAirlineCodes, ['AT']);
      expect(paused.active, isFalse);
      expect(
        alert,
        isNot(FlightAlert.fromJson(const {..._base, 'matchCount': 1})),
      );
    });
  });

  group('FlightAlert.aviasalesSearchPath (repli sur un ancien back)', () {
    final today = DateTime(2026, 10, 13, 15);

    test('aller simple : premier jour de la période', () {
      final alert = _alert(
        from: DateTime(2026, 12),
        to: DateTime(2026, 12, 20),
      );
      expect(alert.aviasalesSearchPath(today), '/search/PAR0112ABJ1');
    });

    test('période entamée : à partir d\'aujourd\'hui', () {
      final alert = _alert(
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 30),
      );
      expect(alert.aviasalesSearchPath(today), '/search/PAR1310ABJ1');
    });

    test('aller-retour : jour du retour ajouté', () {
      final alert = _alert(
        from: DateTime(2026, 12),
        to: DateTime(2026, 12, 20),
        returnFrom: DateTime(2027, 1, 2),
        returnTo: DateTime(2027, 1, 15),
      );
      expect(alert.aviasalesSearchPath(today), '/search/PAR0112ABJ02011');
    });

    test('sans période, période passée ou retour avant l\'aller : rien', () {
      expect(_alert().aviasalesSearchPath(today), isNull);
      expect(
        _alert(
          from: DateTime(2026, 9),
          to: DateTime(2026, 9, 20),
        ).aviasalesSearchPath(today),
        isNull,
      );
      expect(
        _alert(
          from: DateTime(2026, 12, 10),
          to: DateTime(2026, 12, 20),
          returnFrom: DateTime(2026, 12),
          returnTo: DateTime(2026, 12, 5),
        ).aviasalesSearchPath(today),
        isNull,
      );
      expect(
        _alert(
          from: DateTime(2026, 12),
          to: DateTime(2026, 12, 20),
          returnFrom: DateTime(2026, 9),
          returnTo: DateTime(2026, 9, 5),
        ).aviasalesSearchPath(today),
        isNull,
      );
    });

    test('codes manquants : rien', () {
      final alert = FlightAlert(
        id: 'x',
        originCode: '',
        destinationCode: 'ABJ',
        departureFrom: DateTime(2026, 12),
        departureTo: DateTime(2026, 12, 20),
        directOnly: false,
        maxPrice: 1,
        currency: 'EUR',
        active: true,
      );
      expect(alert.aviasalesSearchPath(today), isNull);
    });
  });

  test('FlightAlertOffers : égalité de valeur', () {
    const offer = FlightOffer(
      originCode: 'PAR',
      destinationCode: 'ABJ',
      price: 389,
      currency: 'EUR',
      offerPath: '/search/a',
    );
    const a = FlightAlertOffers(
      alertId: 'a1',
      originCode: 'PAR',
      destinationCode: 'ABJ',
      roundTrip: false,
      currency: 'EUR',
      maxPrice: 450,
      offers: [offer],
    );
    // Pas `const` : deux instances distinctes, comparées champ à champ.
    // ignore: prefer_const_constructors
    final b = FlightAlertOffers(
      alertId: 'a1',
      originCode: 'PAR',
      destinationCode: 'ABJ',
      roundTrip: false,
      currency: 'EUR',
      maxPrice: 450,
      // ignore: prefer_const_literals_to_create_immutables
      offers: [offer],
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.toSearchResult().offers, [offer]);
  });
}
