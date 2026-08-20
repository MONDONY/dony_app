import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/home/bloc/search_composer_bloc.dart';
import 'package:dony/features/home/bloc/search_composer_event.dart';
import 'package:dony/features/home/bloc/search_composer_state.dart';
import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/data/repositories/search_parse_repository.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockParseRepo extends Mock implements SearchParseRepository {}

class _MockAnnouncementRepo extends Mock implements AnnouncementRepository {}

class _MockPackageRepo extends Mock implements PackageRequestRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

SearchParseResult _result({
  Map<String, dynamic> filters = const {},
  List<Map<String, dynamic>> unresolved = const [],
}) => SearchParseResult.fromJson({
  'filters': filters,
  'recognized': const [],
  'unresolved': unresolved,
  'ignored': const [],
});

void main() {
  late _MockParseRepo parseRepo;
  late _MockAnnouncementRepo announcementRepo;
  late _MockPackageRepo packageRepo;
  late _MockAnalytics analytics;

  setUpAll(() {
    registerFallbackValue(null as String?);
    registerFallbackValue(null as bool?);
    registerFallbackValue(null as int?);
    registerFallbackValue(null as double?);
    registerFallbackValue(null as TransportMode?);
    registerFallbackValue(null as DateTime?);
    registerFallbackValue(SearchMode.trips);
  });

  setUp(() {
    parseRepo = _MockParseRepo();
    announcementRepo = _MockAnnouncementRepo();
    packageRepo = _MockPackageRepo();
    analytics = _MockAnalytics();

    // Setup mock pour countAnnouncements - accepte n'importe quels paramètres
    when(
      () => announcementRepo.countAnnouncements(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        departureDateFrom: any(named: 'departureDateFrom'),
        departureDateTo: any(named: 'departureDateTo'),
        minAvailableKg: any(named: 'minAvailableKg'),
        maxAvailableKg: any(named: 'maxAvailableKg'),
        maxPricePerKg: any(named: 'maxPricePerKg'),
        kiloProOnly: any(named: 'kiloProOnly'),
        minRating: any(named: 'minRating'),
        weekendOnly: any(named: 'weekendOnly'),
        transportMode: any(named: 'transportMode'),
        kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
        contentType: any(named: 'contentType'),
        userLat: any(named: 'userLat'),
        userLng: any(named: 'userLng'),
        radiusKm: any(named: 'radiusKm'),
        urgent: any(named: 'urgent'),
      ),
    ).thenAnswer((_) async => 14);
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  SearchComposerBloc build() => SearchComposerBloc(
    parseRepo,
    announcementRepo,
    packageRepo,
    analytics,
    mode: SearchMode.trips,
    initialFilters: const HomeSearchFilters(),
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'une phrase comprise pose les filtres et met à jour le compteur',
    build: () {
      when(() => parseRepo.parse(any(), any())).thenAnswer(
        (_) async => _result(filters: const {'arrivalCity': 'Bamako'}),
      );
      return build();
    },
    act: (bloc) => bloc.add(const SearchComposerPhraseSubmitted('à Bamako')),
    wait: const Duration(milliseconds: 600),
    expect: () => [
      isA<SearchComposerState>().having((s) => s.isParsing, 'isParsing', true),
      isA<SearchComposerState>()
          .having((s) => s.filters.arrivalCity, 'arrivalCity', 'Bamako')
          .having((s) => s.isParsing, 'isParsing', false),
      isA<SearchComposerState>().having(
        (s) => s.isCounting,
        'isCounting',
        true,
      ),
      isA<SearchComposerState>().having(
        (s) => s.resultCount,
        'resultCount',
        14,
      ),
    ],
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'une ambiguïté de prix ne pose aucun filtre de prix',
    build: () {
      when(() => parseRepo.parse(any(), any())).thenAnswer(
        (_) async => _result(
          filters: const {'arrivalCity': 'Kolda'},
          unresolved: const [
            {
              'kind': 'PRICE_VAGUE',
              'phrase': 'pas trop cher',
              'options': ['6', '9'],
            },
          ],
        ),
      );
      return build();
    },
    act: (bloc) =>
        bloc.add(const SearchComposerPhraseSubmitted('à Kolda pas trop cher')),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.filters.maxPricePerKg, isNull);
      expect(bloc.state.unresolved.first.kind, UnresolvedKind.priceVague);
    },
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'répondre à une ambiguïté pose le filtre et retire la question',
    build: () {
      when(() => parseRepo.parse(any(), any())).thenAnswer(
        (_) async => _result(
          unresolved: const [
            {
              'kind': 'PRICE_VAGUE',
              'phrase': 'pas cher',
              'options': ['6', '9'],
            },
          ],
        ),
      );
      return build();
    },
    act: (bloc) async {
      bloc.add(const SearchComposerPhraseSubmitted('pas cher'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      bloc.add(
        const SearchComposerUnresolvedAnswered(
          kind: UnresolvedKind.priceVague,
          value: '6',
        ),
      );
    },
    wait: const Duration(milliseconds: 900),
    verify: (bloc) {
      expect(bloc.state.filters.maxPricePerKg, 6);
      expect(bloc.state.unresolved, isEmpty);
    },
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    '"peu importe" efface un prix déjà réglé et retire la question sans en poser un nouveau',
    build: build,
    seed: () => const SearchComposerState(
      filters: HomeSearchFilters(maxPricePerKg: 9),
      unresolved: [
        UnresolvedItem(
          kind: UnresolvedKind.priceVague,
          phrase: 'pas cher',
          options: ['6', '9'],
        ),
      ],
    ),
    act: (bloc) => bloc.add(
      const SearchComposerUnresolvedAnswered(
        kind: UnresolvedKind.priceVague,
        value: '',
      ),
    ),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.filters.maxPricePerKg, isNull);
      expect(bloc.state.unresolved, isEmpty);
    },
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    '"peu importe" efface une date déjà réglée sans poser de nouvelle contrainte',
    build: build,
    seed: () => const SearchComposerState(
      filters: HomeSearchFilters(datePreset: DonyDatePreset.thisWeek),
      unresolved: [
        UnresolvedItem(
          kind: UnresolvedKind.dateVague,
          phrase: 'bientôt',
          options: [],
        ),
      ],
    ),
    act: (bloc) => bloc.add(
      const SearchComposerUnresolvedAnswered(
        kind: UnresolvedKind.dateVague,
        value: '',
      ),
    ),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.filters.datePreset, DonyDatePreset.none);
      expect(bloc.state.unresolved, isEmpty);
    },
  );

  // ─── I1 : « Cette semaine »/« Ce mois » sont des DonyDatePreset, pas des
  // dates ISO — `unresolved_question.dart` propose ces deux valeurs pour
  // `dateVague`, `DateTime.tryParse` échouait toujours en silence dessus.
  blocTest<SearchComposerBloc, SearchComposerState>(
    '"cette semaine" pose DonyDatePreset.thisWeek plutôt que de ne rien faire',
    build: build,
    seed: () => const SearchComposerState(
      filters: HomeSearchFilters(),
      unresolved: [
        UnresolvedItem(
          kind: UnresolvedKind.dateVague,
          phrase: 'bientôt',
          options: [],
        ),
      ],
    ),
    act: (bloc) => bloc.add(
      const SearchComposerUnresolvedAnswered(
        kind: UnresolvedKind.dateVague,
        value: 'thisWeek',
      ),
    ),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.filters.datePreset, DonyDatePreset.thisWeek);
      expect(bloc.state.unresolved, isEmpty);
    },
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    '"ce mois" pose DonyDatePreset.thisMonth plutôt que de ne rien faire',
    build: build,
    seed: () => const SearchComposerState(
      filters: HomeSearchFilters(),
      unresolved: [
        UnresolvedItem(
          kind: UnresolvedKind.dateVague,
          phrase: 'bientôt',
          options: [],
        ),
      ],
    ),
    act: (bloc) => bloc.add(
      const SearchComposerUnresolvedAnswered(
        kind: UnresolvedKind.dateVague,
        value: 'thisMonth',
      ),
    ),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.filters.datePreset, DonyDatePreset.thisMonth);
      expect(bloc.state.unresolved, isEmpty);
    },
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'un échec réseau laisse les filtres intacts et n efface pas la saisie',
    build: () {
      when(() => parseRepo.parse(any(), any())).thenThrow(Exception('réseau'));
      return build();
    },
    act: (bloc) => bloc.add(const SearchComposerPhraseSubmitted('à Bamako')),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.error, isNotNull);
      expect(bloc.state.filters.arrivalCity, isNull);
    },
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'régler un filtre à la main met le compteur à jour sans appeler le parseur',
    build: build,
    act: (bloc) => bloc.add(
      const SearchComposerFiltersChanged(
        HomeSearchFilters(arrivalCity: 'Dakar'),
      ),
    ),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.resultCount, 14);
      verifyNever(() => parseRepo.parse(any(), any()));
    },
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'deux réglages rapprochés appliquent les DEUX filtres immédiatement, '
    'sans attendre le débounce du comptage réseau',
    build: build,
    act: (bloc) async {
      // Régression : avant le correctif, `debounceTime` portait sur
      // L'ÉVÉNEMENT ENTIER (pas seulement le comptage), retardant l'`emit`
      // des filtres eux-mêmes. Un utilisateur qui pose le départ PUIS
      // l'arrivée PUIS valide, plus vite que les 400 ms de debounce, perdait
      // silencieusement le départ. Un écart de 50 ms (bien en-deçà de
      // 400 ms) reproduit exactement ce scénario.
      bloc.add(
        const SearchComposerFiltersChanged(
          HomeSearchFilters(departureCity: 'Paris'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      bloc.add(
        const SearchComposerFiltersChanged(
          HomeSearchFilters(departureCity: 'Paris', arrivalCity: 'Dakar'),
        ),
      );
    },
    // Volontairement court : la preuve porte sur ce qui est déjà vrai AVANT
    // que le débounce de 400 ms ait eu le temps de courir.
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      expect(bloc.state.filters.departureCity, 'Paris');
      expect(bloc.state.filters.arrivalCity, 'Dakar');
    },
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'un échec du comptage masque le nombre sans casser l écran',
    build: () {
      when(
        () => announcementRepo.countAnnouncements(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
        ),
      ).thenThrow(Exception('réseau'));
      return build();
    },
    act: (bloc) => bloc.add(
      const SearchComposerFiltersChanged(
        HomeSearchFilters(arrivalCity: 'Dakar'),
      ),
    ),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.resultCount, isNull);
      expect(bloc.state.error, isNull);
    },
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'ouvrir l écran mesure l ouverture et compte les filtres hérités',
    build: build,
    act: (bloc) => bloc.add(const SearchComposerStarted()),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.resultCount, 14);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.searchComposerOpened,
          properties: any(named: 'properties'),
        ),
      ).called(1);
    },
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'tout effacer vide les filtres, la phrase et les questions puis recompte',
    build: build,
    seed: () => const SearchComposerState(
      filters: HomeSearchFilters(arrivalCity: 'Dakar'),
      phrase: 'à Dakar pas cher',
      unresolved: [
        UnresolvedItem(
          kind: UnresolvedKind.priceVague,
          phrase: 'pas cher',
          options: ['6'],
        ),
      ],
      resultCount: 3,
    ),
    act: (bloc) => bloc.add(const SearchComposerCleared()),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      // HomeSearchFilters n'a pas d'égalité structurelle (pas d'Equatable) :
      // comparer l'instance entière ne vaut que par accident de
      // canonicalisation `const`. On vérifie donc les champs un par un,
      // seul le corridor (commun) était réglé par le seed.
      expect(bloc.state.filters.arrivalCity, isNull);
      expect(bloc.state.filters.departureCity, isNull);
      expect(bloc.state.phrase, isEmpty);
      expect(bloc.state.unresolved, isEmpty);
      expect(bloc.state.resultCount, 14);
    },
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'tout effacer en mode trips préserve les filtres propres au mode colis',
    build: build,
    seed: () => const SearchComposerState(
      filters: HomeSearchFilters(
        arrivalCity: 'Dakar', // commun : doit être effacé
        kiloProOnly: true, // propre à trips : doit être effacé
        maxWeight: 25, // propre à colis : doit survivre
      ),
    ),
    act: (bloc) => bloc.add(const SearchComposerCleared()),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.filters.arrivalCity, isNull);
      expect(bloc.state.filters.kiloProOnly, isFalse);
      expect(
        bloc.state.filters.maxWeight,
        25,
        reason:
            'un filtre du mode colis ne doit pas disparaître silencieusement '
            'quand on efface depuis le mode trips',
      );
    },
  );

  // ─── I3 : `search_voice_used` se tire dans le BLoC, jamais le widget ──────
  group('search_voice_used', () {
    blocTest<SearchComposerBloc, SearchComposerState>(
      'une phrase dictée trace search_voice_used avec duration_ms',
      build: () {
        when(() => parseRepo.parse(any(), any())).thenAnswer(
          (_) async => _result(filters: const {'arrivalCity': 'Bamako'}),
        );
        return build();
      },
      act: (bloc) => bloc.add(
        const SearchComposerPhraseSubmitted(
          'à Bamako',
          fromVoice: true,
          voiceDurationMs: 2400,
        ),
      ),
      wait: const Duration(milliseconds: 600),
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.searchVoiceUsed,
            properties: {'duration_ms': 2400},
          ),
        ).called(1);
      },
    );

    blocTest<SearchComposerBloc, SearchComposerState>(
      'une phrase tapée au clavier ne trace jamais search_voice_used',
      build: () {
        when(() => parseRepo.parse(any(), any())).thenAnswer(
          (_) async => _result(filters: const {'arrivalCity': 'Bamako'}),
        );
        return build();
      },
      act: (bloc) => bloc.add(const SearchComposerPhraseSubmitted('à Bamako')),
      wait: const Duration(milliseconds: 600),
      verify: (_) {
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.searchVoiceUsed,
            properties: any(named: 'properties'),
          ),
        );
      },
    );
  });

  // ─── I4 : le chemin mode Colis de `_refreshCount` (branche `else`, celle où
  // vivait le bug C2) n'était exercé par aucun test — tous les tests
  // ci-dessus construisent le BLoC en `SearchMode.trips`.
  blocTest<SearchComposerBloc, SearchComposerState>(
    'mode colis : le compteur reflète totalElements du dépôt colis, y '
    'compris avec un filtre maxWeight (couvre aussi la régression C2 : '
    'maxWeight ne doit jamais atterrir sur weightMax)',
    build: () {
      when(
        () => packageRepo.search(
          departure: any(named: 'departure'),
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: any(named: 'maxWeight'),
          parcelSize: any(named: 'parcelSize'),
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
          radiusKm: any(named: 'radiusKm'),
          urgent: any(named: 'urgent'),
          matchingMyTrips: any(named: 'matchingMyTrips'),
          // ignore: avoid_redundant_argument_values
          page: 0,
          size: 1,
        ),
      ).thenAnswer(
        (_) async => const PackageRequestSearchPage(
          content: [],
          totalElements: 7,
          page: 0,
          size: 1,
        ),
      );
      return SearchComposerBloc(
        parseRepo,
        announcementRepo,
        packageRepo,
        analytics,
        mode: SearchMode.parcels,
        initialFilters: const HomeSearchFilters(),
      );
    },
    act: (bloc) => bloc.add(
      const SearchComposerFiltersChanged(HomeSearchFilters(maxWeight: 20)),
    ),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.resultCount, 7);
      expect(bloc.state.filters.maxWeight, 20);
      expect(
        bloc.state.filters.weightMax,
        isNull,
        reason:
            'régression C2 : maxWeight (colis) ne doit jamais polluer '
            'weightMax (trajets)',
      );
      verify(
        () => packageRepo.search(
          departure: any(named: 'departure'),
          arrival: any(named: 'arrival'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          maxWeight: 20,
          parcelSize: any(named: 'parcelSize'),
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
          radiusKm: any(named: 'radiusKm'),
          urgent: any(named: 'urgent'),
          matchingMyTrips: any(named: 'matchingMyTrips'),
          // ignore: avoid_redundant_argument_values
          page: 0,
          size: 1,
        ),
      ).called(1);
    },
  );
}
