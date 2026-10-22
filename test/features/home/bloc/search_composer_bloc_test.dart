import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/home/bloc/search_composer_bloc.dart';
import 'package:dony/features/home/bloc/search_composer_event.dart';
import 'package:dony/features/home/bloc/search_composer_state.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/matching/data/models/urgency_filter.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncementRepo extends Mock implements AnnouncementRepository {}

class _MockPackageRepo extends Mock implements PackageRequestRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
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
        gpProOnly: any(named: 'gpProOnly'),
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
    announcementRepo,
    packageRepo,
    analytics,
    mode: SearchMode.trips,
    initialFilters: const HomeSearchFilters(),
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'régler un filtre à la main met le compteur à jour',
    build: build,
    act: (bloc) => bloc.add(
      const SearchComposerFiltersChanged(
        HomeSearchFilters(arrivalCity: 'Dakar'),
      ),
    ),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.resultCount, 14);
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
    'le filtre d urgence part au comptage : le compteur du bas suit '
    '(FLUTTER-MH)',
    build: build,
    act: (bloc) => bloc.add(
      const SearchComposerFiltersChanged(
        HomeSearchFilters(urgencyFilter: UrgencyFilter.veryUrgent),
      ),
    ),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      final n = DateTime.now();
      final today = DateTime(n.year, n.month, n.day);
      verify(
        () => announcementRepo.countAnnouncements(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          departureDateFrom: today,
          departureDateTo: DateTime(n.year, n.month, n.day + 2),
          minAvailableKg: any(named: 'minAvailableKg'),
          maxAvailableKg: any(named: 'maxAvailableKg'),
          maxPricePerKg: any(named: 'maxPricePerKg'),
          gpProOnly: any(named: 'gpProOnly'),
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
      ).called(1);
      expect(bloc.state.resultCount, 14);
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
    'tout effacer vide les filtres puis recompte',
    build: build,
    seed: () => const SearchComposerState(
      filters: HomeSearchFilters(arrivalCity: 'Dakar'),
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
      expect(bloc.state.resultCount, 14);
    },
  );

  blocTest<SearchComposerBloc, SearchComposerState>(
    'tout effacer en mode trips préserve les filtres propres au mode colis',
    build: build,
    seed: () => const SearchComposerState(
      filters: HomeSearchFilters(
        arrivalCity: 'Dakar', // commun : doit être effacé
        gpProOnly: true, // propre à trips : doit être effacé
        maxWeight: 25, // propre à colis : doit survivre
      ),
    ),
    act: (bloc) => bloc.add(const SearchComposerCleared()),
    wait: const Duration(milliseconds: 600),
    verify: (bloc) {
      expect(bloc.state.filters.arrivalCity, isNull);
      expect(bloc.state.filters.gpProOnly, isFalse);
      expect(
        bloc.state.filters.maxWeight,
        25,
        reason:
            'un filtre du mode colis ne doit pas disparaître silencieusement '
            'quand on efface depuis le mode trips',
      );
    },
  );

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

  // ─── Période choisie au calendrier : les deux bornes partent au serveur.
  group('période du … au …', () {
    final start = DateTime(2026, 11, 15);
    final end = DateTime(2026, 12, 15);
    final period = const HomeSearchFilters().withCustomPeriod(start, end);

    blocTest<SearchComposerBloc, SearchComposerState>(
      'mode trajets : le compteur reçoit le début et la fin',
      build: build,
      act: (bloc) => bloc.add(SearchComposerFiltersChanged(period)),
      wait: const Duration(milliseconds: 600),
      verify: (bloc) {
        expect(bloc.state.filters.customDateTo, end);
        verify(
          () => announcementRepo.countAnnouncements(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDateFrom: start,
            departureDateTo: end,
            minAvailableKg: any(named: 'minAvailableKg'),
            maxAvailableKg: any(named: 'maxAvailableKg'),
            maxPricePerKg: any(named: 'maxPricePerKg'),
            gpProOnly: any(named: 'gpProOnly'),
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
        ).called(1);
      },
    );

    blocTest<SearchComposerBloc, SearchComposerState>(
      'mode colis : la recherche de demandes reçoit dateFrom et dateTo',
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
            totalElements: 3,
            page: 0,
            size: 1,
          ),
        );
        return SearchComposerBloc(
          announcementRepo,
          packageRepo,
          analytics,
          mode: SearchMode.parcels,
          initialFilters: const HomeSearchFilters(),
        );
      },
      act: (bloc) => bloc.add(SearchComposerFiltersChanged(period)),
      wait: const Duration(milliseconds: 600),
      verify: (bloc) {
        expect(bloc.state.resultCount, 3);
        verify(
          () => packageRepo.search(
            departure: any(named: 'departure'),
            arrival: any(named: 'arrival'),
            dateFrom: start,
            dateTo: end,
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
        ).called(1);
      },
    );
  });
}
