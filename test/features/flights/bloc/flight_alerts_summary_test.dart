import 'package:dony/features/flights/bloc/flight_alerts_summary.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:flutter_test/flutter_test.dart';

FlightAlert _alert(
  String id, {
  double max = 450,
  double? seen,
  int? count,
  bool active = true,
  String currency = 'EUR',
}) => FlightAlert(
  id: id,
  originCode: 'PAR',
  destinationCode: 'ABJ',
  directOnly: false,
  maxPrice: max,
  currency: currency,
  active: active,
  lastSeenPrice: seen,
  matchCount: count,
);

void main() {
  test('aucune alerte : empty', () {
    final s = FlightAlertsSummary.of(const []);
    expect(s.kind, FlightAlertsSummaryKind.empty);
    expect(s.kind.analyticsValue, 'empty');
    expect(s.price, isNull);
    expect(s.savings, isNull);
  });

  test('un prix trouvé : prix et écart de cette alerte', () {
    final s = FlightAlertsSummary.of([
      _alert('a', seen: 389, count: 3),
      _alert('b', max: 300, seen: 412, count: 0),
    ]);
    expect(s.kind, FlightAlertsSummaryKind.hit);
    expect(s.kind.analyticsValue, 'hit');
    expect(s.hitCount, 1);
    expect(s.activeCount, 2);
    expect(s.best!.id, 'a');
    expect(s.price, 389);
    expect(s.currency, 'EUR');
    expect(s.savings, 61);
  });

  test('plusieurs prix trouvés : le meilleur, écart sur son alerte', () {
    final s = FlightAlertsSummary.of([
      _alert('a', seen: 389, count: 3),
      _alert('b', max: 300, seen: 280, count: 2),
    ]);
    expect(s.hitCount, 2);
    expect(s.best!.id, 'b');
    expect(s.price, 280);
    expect(s.savings, 20);
  });

  test('une alerte en pause ne compte pas comme un prix trouvé', () {
    final s = FlightAlertsSummary.of([
      _alert('a', seen: 300, count: 2, active: false),
      _alert('b', seen: 512, count: 0),
    ]);
    expect(s.kind, FlightAlertsSummaryKind.noHit);
    expect(s.kind.analyticsValue, 'no_hit');
    expect(s.activeCount, 1);
    expect(s.price, 512);
  });

  test('rien sous le seuil : plus bas prix vu, dans une seule devise', () {
    final s = FlightAlertsSummary.of([
      _alert('a', seen: 520, count: 0),
      _alert('x', seen: 150000, count: 0, currency: 'XOF'),
      _alert('b', seen: 480, count: 0),
      _alert('c'),
    ]);
    expect(s.kind, FlightAlertsSummaryKind.noHit);
    expect(s.price, 480);
    expect(s.currency, 'EUR');
    expect(s.best!.id, 'b');
  });

  test('rien de vérifié : pas de prix', () {
    final s = FlightAlertsSummary.of([_alert('a'), _alert('b')]);
    expect(s.kind, FlightAlertsSummaryKind.noHit);
    expect(s.price, isNull);
    expect(s.best, isNull);
  });

  test('prix trouvé sans prix connu (donnée incomplète) : pas de prix', () {
    final s = FlightAlertsSummary.of([_alert('a', count: 2)]);
    expect(s.kind, FlightAlertsSummaryKind.hit);
    expect(s.best!.id, 'a');
    expect(s.price, isNull);
    expect(s.savings, isNull);
  });

  test('égalité de valeur', () {
    final list = [_alert('a', seen: 389, count: 3)];
    expect(FlightAlertsSummary.of(list), FlightAlertsSummary.of(list));
  });

  test('dernier prix périmé (sous le seuil, plus rien trouvé) : ignoré', () {
    final s = FlightAlertsSummary.of([
      _alert('stale', seen: 300, count: 0),
      _alert('b', seen: 512, count: 0),
    ]);
    expect(s.kind, FlightAlertsSummaryKind.noHit);
    expect(s.price, 512);
    expect(
      FlightAlertsSummary.of([_alert('stale', seen: 300, count: 0)]).price,
      isNull,
    );
  });
}
