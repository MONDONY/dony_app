import 'package:dony/features/flights/data/models/flight_passengers.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:flutter_test/flutter_test.dart';

const _paris = FlightPlace(code: 'PAR', name: 'Paris');
const _dakar = FlightPlace(code: 'DKR', name: 'Dakar');

void main() {
  group('FlightPassengers', () {
    test('un adulte par défaut, égalité par valeur', () {
      const p = FlightPassengers();
      expect(p, FlightPassengers.single);
      expect(p.isSingle, isTrue);
      expect(p.total, 1);
      expect(p.adultsOnly, isTrue);
      expect(p.props, [1, 0, 0]);
      expect(
        const FlightPassengers(adults: 2, children: 1),
        isNot(const FlightPassengers(adults: 2, infants: 1)),
      );
      expect(const FlightPassengers(adults: 2, children: 1).key, '2-1-0');
    });

    test('validations du back', () {
      expect(const FlightPassengers(adults: 9).isValid, isTrue);
      expect(const FlightPassengers(adults: 0).isValid, isFalse);
      expect(const FlightPassengers(adults: 10).isValid, isFalse);
      expect(const FlightPassengers(children: 8).isValid, isTrue);
      expect(const FlightPassengers(adults: 2, children: 8).isValid, isFalse);
      expect(const FlightPassengers(infants: 2).isValid, isFalse);
      expect(const FlightPassengers(children: -1).isValid, isFalse);
      expect(
        const FlightPassengers(adults: 3, children: 3, infants: 3).isValid,
        isTrue,
      );
    });

    test('compteurs : bornes du − et du +', () {
      const p = FlightPassengers.single;
      expect(p.canDecrement(FlightPassengerKind.adults), isFalse);
      expect(p.canDecrement(FlightPassengerKind.children), isFalse);
      expect(p.canDecrement(FlightPassengerKind.infants), isFalse);
      expect(p.decrement(FlightPassengerKind.adults), p);

      final baby = p.increment(FlightPassengerKind.infants);
      expect(baby.infants, 1);
      expect(baby.canIncrement(FlightPassengerKind.infants), isFalse);
      expect(baby.increment(FlightPassengerKind.infants), baby);

      final two = baby.increment(FlightPassengerKind.adults);
      expect(two.canIncrement(FlightPassengerKind.infants), isTrue);
      final twoBabies = two.increment(FlightPassengerKind.infants);
      // Deux adultes, deux bébés : retirer un adulte laisserait un bébé seul.
      expect(twoBabies.canDecrement(FlightPassengerKind.adults), isFalse);
      expect(
        twoBabies
            .decrement(FlightPassengerKind.infants)
            .canDecrement(FlightPassengerKind.adults),
        isTrue,
      );

      const full = FlightPassengers(adults: 5, children: 4);
      expect(full.total, FlightPassengers.maxTotal);
      for (final kind in FlightPassengerKind.values) {
        expect(full.canIncrement(kind), isFalse);
        expect(full.increment(kind), full);
      }
      expect(full.count(FlightPassengerKind.children), 4);
    });

    test('JSON et lecture tolérante', () {
      const p = FlightPassengers(adults: 2, children: 1, infants: 1);
      expect(p.toJson(), {'adults': 2, 'children': 1, 'infants': 1});
      expect(FlightPassengers.tryParse(p.toJson()), p);
      expect(FlightPassengers.tryParse(null), FlightPassengers.single);
      expect(FlightPassengers.tryParse('x'), FlightPassengers.single);
      expect(
        FlightPassengers.tryParse(const {'adults': 2}),
        const FlightPassengers(adults: 2),
      );
      expect(
        FlightPassengers.tryParse(const {'adults': 0}),
        FlightPassengers.single,
      );
    });
  });

  group('FlightSearchQuery : passagers', () {
    const family = FlightPassengers(adults: 2, children: 2);

    test('un adulte par défaut, gardé par copyWith et swapped', () {
      const q = FlightSearchQuery(origin: _paris, destination: _dakar);
      expect(q.passengers, FlightPassengers.single);

      final withFamily = q.copyWith(passengers: family);
      expect(withFamily.passengers, family);
      expect(withFamily, isNot(q));
      expect(withFamily.props, contains(family));
      expect(withFamily.copyWith(directOnly: true).passengers, family);

      final swapped = withFamily.swapped();
      expect(swapped.passengers, family);
      expect(swapped.origin, _dakar);
    });
  });
}
