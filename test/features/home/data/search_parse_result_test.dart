import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('wireModeOf', () {
    test('trips devient TRIPS', () {
      expect(wireModeOf(SearchMode.trips), 'TRIPS');
    });

    test('parcels devient PACKAGES et non PARCELS', () {
      // Le backend nomme ce mode PACKAGES : le mapping est explicite pour que
      // personne ne le devine à partir du nom Flutter.
      expect(wireModeOf(SearchMode.parcels), 'PACKAGES');
    });
  });

  group('SearchParseResult.fromJson', () {
    test('lit les filtres, les champs reconnus et les ambiguïtés', () {
      final result = SearchParseResult.fromJson(const {
        'filters': {
          'arrivalCity': 'Bamako',
          'departureDateFrom': '2027-03-01',
          'departureDateTo': '2027-03-31',
          'minAvailableKg': 20,
        },
        'recognized': [
          {'field': 'arrivalCity', 'value': 'Bamako', 'confidence': 0.98},
        ],
        'unresolved': [],
        'ignored': ['en'],
      });

      expect(result.recognized, hasLength(1));
      expect(result.recognized.first.field, 'arrivalCity');
      expect(result.unresolved, isEmpty);
    });

    test('un filtre absent du json reste absent, il ne devient pas zéro', () {
      final result = SearchParseResult.fromJson(const {
        'filters': {'arrivalCity': 'Dakar'},
        'recognized': [],
        'unresolved': [],
        'ignored': [],
      });

      final applied = result.applyTo(const HomeSearchFilters());

      expect(applied.arrivalCity, 'Dakar');
      expect(applied.maxPricePerKg, isNull);
      expect(applied.weightMin, isNull);
    });

    test('lit une ambiguïté de prix avec ses options', () {
      final result = SearchParseResult.fromJson(const {
        'filters': {},
        'recognized': [],
        'unresolved': [
          {'kind': 'PRICE_VAGUE', 'phrase': 'pas trop cher', 'options': ['6', '9', 'unlimited']},
        ],
        'ignored': [],
      });

      expect(result.unresolved, hasLength(1));
      expect(result.unresolved.first.kind, UnresolvedKind.priceVague);
      expect(result.unresolved.first.options, ['6', '9', 'unlimited']);
    });

    test('une ambiguïté de type inconnu est ignorée plutôt que de faire planter', () {
      final result = SearchParseResult.fromJson(const {
        'filters': {},
        'recognized': [],
        'unresolved': [
          {'kind': 'SOMETHING_NEW', 'phrase': 'x', 'options': []},
        ],
        'ignored': [],
      });

      expect(result.unresolved, isEmpty);
    });
  });

  group('applyTo', () {
    test('conserve les filtres déjà posés que la phrase ne mentionne pas', () {
      const base = HomeSearchFilters(departureCity: 'Paris', urgentOnly: true);
      final result = SearchParseResult.fromJson(const {
        'filters': {'arrivalCity': 'Dakar'},
        'recognized': [],
        'unresolved': [],
        'ignored': [],
      });

      final applied = result.applyTo(base);

      expect(applied.departureCity, 'Paris');
      expect(applied.urgentOnly, isTrue);
      expect(applied.arrivalCity, 'Dakar');
    });
  });
}
