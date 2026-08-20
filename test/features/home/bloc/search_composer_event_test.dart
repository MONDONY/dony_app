// Tests d'égalité des events `SearchComposerEvent` — classes `Equatable`
// triviales, jamais exercées directement par `blocTest` (qui compare des
// STATES, pas les events en entrée). Sans ce fichier, les `props` getters et
// certains constructeurs ne sont jamais évalués par la suite.

import 'package:dony/features/home/bloc/search_composer_event.dart';
import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchComposerStarted', () {
    test('deux instances sont égales (aucune prop)', () {
      expect(const SearchComposerStarted(), const SearchComposerStarted());
    });

    test('n\'est pas égal à un autre event', () {
      expect(
        const SearchComposerStarted(),
        isNot(const SearchComposerCleared()),
      );
    });
  });

  group('SearchComposerPhraseSubmitted', () {
    test('égal avec le même texte', () {
      expect(
        const SearchComposerPhraseSubmitted('à Bamako'),
        const SearchComposerPhraseSubmitted('à Bamako'),
      );
    });

    test('différent si le texte diffère', () {
      expect(
        const SearchComposerPhraseSubmitted('à Bamako'),
        isNot(const SearchComposerPhraseSubmitted('à Dakar')),
      );
    });

    test('expose text', () {
      const event = SearchComposerPhraseSubmitted('pas trop cher');
      expect(event.text, 'pas trop cher');
    });
  });

  group('SearchComposerFiltersChanged', () {
    test('égal avec les mêmes filtres', () {
      const filters = HomeSearchFilters(departureCity: 'Paris');
      expect(
        const SearchComposerFiltersChanged(filters),
        const SearchComposerFiltersChanged(filters),
      );
    });

    test('différent si les filtres diffèrent', () {
      expect(
        const SearchComposerFiltersChanged(
          HomeSearchFilters(departureCity: 'Paris'),
        ),
        isNot(
          const SearchComposerFiltersChanged(
            HomeSearchFilters(departureCity: 'Lyon'),
          ),
        ),
      );
    });

    test('expose filters', () {
      const filters = HomeSearchFilters(arrivalCity: 'Dakar');
      const event = SearchComposerFiltersChanged(filters);
      expect(event.filters, filters);
    });
  });

  group('SearchComposerUnresolvedAnswered', () {
    test('égal avec le même kind et la même value', () {
      expect(
        const SearchComposerUnresolvedAnswered(
          kind: UnresolvedKind.priceVague,
          value: '6',
        ),
        const SearchComposerUnresolvedAnswered(
          kind: UnresolvedKind.priceVague,
          value: '6',
        ),
      );
    });

    test('différent si le kind diffère (même value)', () {
      expect(
        const SearchComposerUnresolvedAnswered(
          kind: UnresolvedKind.priceVague,
          value: '',
        ),
        isNot(
          const SearchComposerUnresolvedAnswered(
            kind: UnresolvedKind.dateVague,
            value: '',
          ),
        ),
      );
    });

    test('différent si la value diffère (même kind)', () {
      expect(
        const SearchComposerUnresolvedAnswered(
          kind: UnresolvedKind.cityAmbiguous,
          value: 'Bamako',
        ),
        isNot(
          const SearchComposerUnresolvedAnswered(
            kind: UnresolvedKind.cityAmbiguous,
            value: 'Dakar',
          ),
        ),
      );
    });

    test('expose kind et value', () {
      const event = SearchComposerUnresolvedAnswered(
        kind: UnresolvedKind.cityUnknown,
        value: 'Lomé',
      );
      expect(event.kind, UnresolvedKind.cityUnknown);
      expect(event.value, 'Lomé');
    });
  });

  group('SearchComposerCleared', () {
    test('deux instances sont égales (aucune prop)', () {
      expect(const SearchComposerCleared(), const SearchComposerCleared());
    });

    test('n\'est pas égal à un autre event', () {
      expect(
        const SearchComposerCleared(),
        isNot(const SearchComposerStarted()),
      );
    });
  });
}
