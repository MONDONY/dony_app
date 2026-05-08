import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CitySearchQueryChanged', () {
    test('stocke la query passée en paramètre', () {
      const event = CitySearchQueryChanged('Paris');
      expect(event.query, 'Paris');
    });

    test('est une instance de CitySearchEvent', () {
      const event = CitySearchQueryChanged('Dakar');
      expect(event, isA<CitySearchEvent>());
    });

    test('query vide est acceptée', () {
      const event = CitySearchQueryChanged('');
      expect(event.query, isEmpty);
    });
  });

  group('CitySearchCleared', () {
    test('est une instance de CitySearchEvent', () {
      const event = CitySearchCleared();
      expect(event, isA<CitySearchEvent>());
    });

    test('peut être instancié en const', () {
      const event1 = CitySearchCleared();
      const event2 = CitySearchCleared();
      expect(event1, isA<CitySearchCleared>());
      expect(event2, isA<CitySearchCleared>());
    });
  });
}
