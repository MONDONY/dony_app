import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
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
          {
            'kind': 'PRICE_VAGUE',
            'phrase': 'pas trop cher',
            'options': ['6', '9', 'unlimited'],
          },
        ],
        'ignored': [],
      });

      expect(result.unresolved, hasLength(1));
      expect(result.unresolved.first.kind, UnresolvedKind.priceVague);
      expect(result.unresolved.first.options, ['6', '9', 'unlimited']);
    });

    test(
      'une ambiguïté de type inconnu est ignorée plutôt que de faire planter',
      () {
        final result = SearchParseResult.fromJson(const {
          'filters': {},
          'recognized': [],
          'unresolved': [
            {'kind': 'SOMETHING_NEW', 'phrase': 'x', 'options': []},
          ],
          'ignored': [],
        });

        expect(result.unresolved, isEmpty);
      },
    );
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

    // I5 : couvre les 14 champs possibles du contrat backend, avec leur
    // vraie valeur attendue — pas seulement `recognized`/`unresolved`.
    test(
      'pose chaque champ reconnu sur son homologue Flutter exact '
      '(C1 date + preset, C2 maxWeight, C3 les 6 champs jusque-là ignorés)',
      () {
        final result = SearchParseResult.fromJson(const {
          'filters': {
            'arrivalCity': 'Bamako',
            'departureCity': 'Paris',
            'departureDateFrom': '2027-03-01',
            'departureDateTo': '2027-03-31',
            'minAvailableKg': 20,
            'maxWeight': 15,
            'maxPricePerKg': 8.5,
            'urgent': true,
            'kiloProOnly': true,
            'kycVerifiedOnly': true,
            'minRating': 4.5,
            'weekendOnly': true,
            'contentType': 'Électronique',
            'transportMode': 'PLANE',
          },
          'recognized': [],
          'unresolved': [],
          'ignored': [],
        });

        final applied = result.applyTo(const HomeSearchFilters());

        expect(applied.arrivalCity, 'Bamako');
        expect(applied.departureCity, 'Paris');

        // C1 : `datePreset` DOIT passer à `custom` en même temps que
        // `customDate`, sinon `dateFrom`/`dateTo` (qui ne lisent `customDate`
        // qu'en mode `custom`) renvoient `null` et la date n'a aucun effet.
        expect(applied.datePreset, DonyDatePreset.custom);
        expect(applied.customDate, DateTime.parse('2027-03-01'));
        expect(applied.dateFrom, DateTime.parse('2027-03-01'));
        // `departureDateTo` est ignoré volontairement (modèle à date unique) :
        // `dateTo` retombe donc sur la même valeur que `dateFrom`, jamais sur
        // le 2027-03-31 envoyé par le serveur.
        expect(applied.dateTo, DateTime.parse('2027-03-01'));

        expect(applied.weightMin, 20);

        // C2 : `maxWeight` (colis) va vers `HomeSearchFilters.maxWeight`,
        // jamais vers `weightMax` (trajets) — c'était le bug.
        expect(applied.maxWeight, 15);
        expect(applied.weightMax, isNull);

        expect(applied.maxPricePerKg, 8.5);
        expect(applied.urgentOnly, isTrue);

        // C3 : les 6 champs jusque-là jamais mappés.
        expect(applied.kiloProOnly, isTrue);
        expect(applied.kycVerifiedOnly, isTrue);
        expect(applied.minRating, 4.5);
        expect(applied.weekendOnly, isTrue);
        expect(applied.contentType, 'Électronique');
        expect(applied.transportMode, TransportMode.plane);
      },
    );

    test('un transportMode inconnu du serveur est ignoré plutôt que de faire '
        'planter (C3, même contrat que UnresolvedKind.fromWire)', () {
      final result = SearchParseResult.fromJson(const {
        'filters': {'transportMode': 'ROCKET'},
        'recognized': [],
        'unresolved': [],
        'ignored': [],
      });

      final applied = result.applyTo(const HomeSearchFilters());

      expect(applied.transportMode, isNull);
    });

    test('applyTo ne dépend pas du mode : le serveur ne renvoie maxWeight que '
        'pour une réponse PACKAGES, donc le mapper vers le champ colis, sans '
        'jamais consulter SearchMode ici, reste cohérent avec C2', () {
      // Ce test documente l'absence de paramètre `SearchMode` sur `applyTo`
      // (voir la signature) : le serveur adapte déjà `filters` au mode
      // demandé (`SearchParseRepository.parse(text, mode)`), donc
      // `maxWeight` n'apparaît jamais dans une réponse TRIPS. Aucune
      // incohérence détectée avec le correctif C2.
      final result = SearchParseResult.fromJson(const {
        'filters': {'maxWeight': 12},
        'recognized': [],
        'unresolved': [],
        'ignored': [],
      });

      final applied = result.applyTo(const HomeSearchFilters());

      expect(applied.maxWeight, 12);
      expect(applied.weightMax, isNull);
    });
  });
}
