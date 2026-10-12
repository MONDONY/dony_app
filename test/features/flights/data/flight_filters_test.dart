import 'package:dony/features/flights/data/models/flight_filters.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:flutter_test/flutter_test.dart';

FlightOffer _offer(
  String path, {
  required double price,
  int? transfers,
  int? minutes,
  String? airline,
  String? gate,
}) => FlightOffer(
  originCode: 'PAR',
  destinationCode: 'ABJ',
  price: price,
  currency: 'EUR',
  airlineCode: airline,
  airlineName: airline == null ? null : 'Compagnie $airline',
  transfers: transfers,
  durationMinutes: minutes,
  gate: gate,
  offerPath: path,
);

void main() {
  final cheapOneStop = _offer(
    'a',
    price: 431,
    transfers: 1,
    minutes: 585,
    airline: 'AT',
    gate: 'Kiwi.com',
  );
  final direct = _offer(
    'b',
    price: 489,
    transfers: 0,
    minutes: 380,
    airline: 'AF',
    gate: 'Aviasales',
  );
  final twoStops = _offer(
    'c',
    price: 455,
    transfers: 2,
    minutes: 900,
    airline: 'AT',
    gate: 'Aviasales',
  );
  final unknown = _offer('d', price: 470);
  final offers = [direct, twoStops, cheapOneStop, unknown];

  test(
    'tri par prix, par durée et par escales ; l\'inconnu passe en dernier',
    () {
      expect(const FlightFilters().apply(offers).map((o) => o.offerPath), [
        'a',
        'c',
        'd',
        'b',
      ]);
      expect(
        const FlightFilters(
          sort: FlightSort.fastest,
        ).apply(offers).map((o) => o.offerPath),
        ['b', 'a', 'c', 'd'],
      );
      expect(
        const FlightFilters(
          sort: FlightSort.fewestStops,
        ).apply(offers).map((o) => o.offerPath),
        ['b', 'a', 'c', 'd'],
      );
    },
  );

  test('escales : direct, ou une au plus (escales inconnues écartées)', () {
    expect(const FlightFilters(stops: FlightStops.direct).apply(offers), [
      direct,
    ]);
    expect(const FlightFilters(stops: FlightStops.oneMax).apply(offers), [
      cheapOneStop,
      direct,
    ]);
  });

  test('compagnies, sites et fourchette de prix se cumulent', () {
    const filters = FlightFilters(
      airlines: {'AT'},
      gates: {'Aviasales'},
      minPrice: 440,
      maxPrice: 460,
    );
    expect(filters.apply(offers), [twoStops]);
    expect(filters.isFiltering, isTrue);
    expect(const FlightFilters(sort: FlightSort.fastest).isFiltering, isFalse);
  });

  test('copyWith peut retirer une borne de prix', () {
    const f = FlightFilters(minPrice: 10, maxPrice: 20);
    final cleared = f.copyWith(clearMinPrice: true);
    expect(cleared.minPrice, isNull);
    expect(cleared.maxPrice, 20);
  });

  test(
    'facettes : prix mini par compagnie et par site, fourchette globale',
    () {
      final facets = FlightFacets.of(offers);

      expect(facets.minPrice, 431);
      expect(facets.maxPrice, 489);
      expect(facets.airlines.map((a) => (a.code, a.minPrice)), [
        ('AT', 431.0),
        ('AF', 489.0),
      ]);
      expect(facets.gates.map((g) => (g.name, g.minPrice)), [
        ('Kiwi.com', 431.0),
        ('Aviasales', 455.0),
      ]);
    },
  );
}
