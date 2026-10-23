import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/profile/bloc/open_listings_cubit.dart';
import 'package:dony/features/profile/data/models/open_listing.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';
import '../data/models/open_listing_test.dart' show requestJson, tripJson;

class _MockProfileRepository extends Mock implements ProfileRepository {}

OpenListing _trip() => OpenListing.fromJson({
  'kind': 'TRIP',
  'publishedAt': '2026-10-20T09:00:00',
  'trip': tripJson(),
})!;

OpenListing _request() => OpenListing.fromJson({
  'kind': 'REQUEST',
  'publishedAt': '2026-10-21T18:00:00',
  'request': requestJson(),
})!;

void main() {
  late _MockProfileRepository repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockProfileRepository();
    backend = MockAnalyticsBackend();
  });

  OpenListingsCubit build() {
    final analytics = makeEnabledAnalytics(backend)..onConfigured();
    return OpenListingsCubit(repo, analytics);
  }

  group('load', () {
    blocTest<OpenListingsCubit, OpenListingsState>(
      'charge les annonces et mesure la vue (nombre de trajets et de demandes)',
      setUp: () => when(
        () => repo.getOpenListings('u1'),
      ).thenAnswer((_) async => [_request(), _trip()]),
      build: build,
      act: (c) => c.load('u1'),
      expect: () => [
        isA<OpenListingsLoading>(),
        isA<OpenListingsLoaded>()
            .having((s) => s.items.length, 'items', 2)
            .having((s) => s.tripCount, 'tripCount', 1)
            .having((s) => s.requestCount, 'requestCount', 1)
            .having((s) => s.filter, 'filter', OpenListingsFilter.all),
      ],
      verify: (_) => verify(
        () => backend.capture(AnalyticsEvents.openListingsViewed, {
          'trip_count': 1,
          'request_count': 1,
        }),
      ).called(1),
    );

    blocTest<OpenListingsCubit, OpenListingsState>(
      'un échec masque la section et ne mesure rien',
      setUp: () => when(
        () => repo.getOpenListings('u1'),
      ).thenThrow(const NotFoundException()),
      build: build,
      act: (c) => c.load('u1'),
      expect: () => [isA<OpenListingsLoading>(), isA<OpenListingsFailed>()],
      verify: (_) => verifyNever(
        () => backend.capture(AnalyticsEvents.openListingsViewed, any()),
      ),
    );

    blocTest<OpenListingsCubit, OpenListingsState>(
      'sans identifiant, rien n\'est demandé',
      build: build,
      act: (c) => c.load(''),
      expect: () => <OpenListingsState>[],
      verify: (_) => verifyNever(() => repo.getOpenListings(any())),
    );

    blocTest<OpenListingsCubit, OpenListingsState>(
      'une liste vide est un état chargé, pas un échec',
      setUp: () => when(
        () => repo.getOpenListings('u1'),
      ).thenAnswer((_) async => <OpenListing>[]),
      build: build,
      act: (c) => c.load('u1'),
      expect: () => [
        isA<OpenListingsLoading>(),
        isA<OpenListingsLoaded>().having((s) => s.items, 'items', isEmpty),
      ],
    );
  });

  group('selectFilter', () {
    blocTest<OpenListingsCubit, OpenListingsState>(
      'filtre les trajets puis les demandes, ordre conservé, et mesure',
      setUp: () => when(
        () => repo.getOpenListings('u1'),
      ).thenAnswer((_) async => [_request(), _trip()]),
      build: build,
      act: (c) async {
        await c.load('u1');
        c
          ..selectFilter(OpenListingsFilter.trips)
          ..selectFilter(OpenListingsFilter.requests);
      },
      skip: 2,
      expect: () => [
        isA<OpenListingsLoaded>()
            .having((s) => s.filter, 'filter', OpenListingsFilter.trips)
            .having((s) => s.visible.single, 'visible', isA<OpenTripListing>()),
        isA<OpenListingsLoaded>()
            .having((s) => s.filter, 'filter', OpenListingsFilter.requests)
            .having(
              (s) => s.visible.single,
              'visible',
              isA<OpenRequestListing>(),
            ),
      ],
      verify: (_) {
        verify(
          () => backend.capture(AnalyticsEvents.openListingsFilterChanged, {
            'filter': 'trips',
          }),
        ).called(1);
        verify(
          () => backend.capture(AnalyticsEvents.openListingsFilterChanged, {
            'filter': 'requests',
          }),
        ).called(1);
      },
    );

    blocTest<OpenListingsCubit, OpenListingsState>(
      'rouvrir le filtre courant ne change rien et ne mesure rien',
      setUp: () => when(
        () => repo.getOpenListings('u1'),
      ).thenAnswer((_) async => [_trip()]),
      build: build,
      act: (c) async {
        await c.load('u1');
        c.selectFilter(OpenListingsFilter.all);
      },
      skip: 2,
      expect: () => <OpenListingsState>[],
      verify: (_) => verifyNever(
        () => backend.capture(AnalyticsEvents.openListingsFilterChanged, any()),
      ),
    );

    blocTest<OpenListingsCubit, OpenListingsState>(
      'avant le chargement, le filtre est sans effet',
      build: build,
      act: (c) => c.selectFilter(OpenListingsFilter.trips),
      expect: () => <OpenListingsState>[],
    );
  });

  group('toggleExpanded', () {
    blocTest<OpenListingsCubit, OpenListingsState>(
      'déplié par défaut ; replie puis déplie, filtre et annonces gardés, et mesure',
      setUp: () => when(
        () => repo.getOpenListings('u1'),
      ).thenAnswer((_) async => [_request(), _trip()]),
      build: build,
      act: (c) async {
        await c.load('u1');
        c
          ..selectFilter(OpenListingsFilter.trips)
          ..toggleExpanded()
          ..toggleExpanded();
      },
      skip: 3,
      expect: () => [
        isA<OpenListingsLoaded>()
            .having((s) => s.expanded, 'expanded', isFalse)
            .having((s) => s.filter, 'filter', OpenListingsFilter.trips)
            .having((s) => s.items.length, 'items', 2),
        isA<OpenListingsLoaded>()
            .having((s) => s.expanded, 'expanded', isTrue)
            .having((s) => s.filter, 'filter', OpenListingsFilter.trips),
      ],
      verify: (_) {
        verify(
          () => backend.capture(AnalyticsEvents.openListingsToggled, {
            'expanded': false,
          }),
        ).called(1);
        verify(
          () => backend.capture(AnalyticsEvents.openListingsToggled, {
            'expanded': true,
          }),
        ).called(1);
      },
    );

    blocTest<OpenListingsCubit, OpenListingsState>(
      'changer de filtre une fois replié garde la section repliée',
      setUp: () => when(
        () => repo.getOpenListings('u1'),
      ).thenAnswer((_) async => [_request(), _trip()]),
      build: build,
      act: (c) async {
        await c.load('u1');
        c
          ..toggleExpanded()
          ..selectFilter(OpenListingsFilter.requests);
      },
      skip: 3,
      expect: () => [
        isA<OpenListingsLoaded>()
            .having((s) => s.expanded, 'expanded', isFalse)
            .having((s) => s.filter, 'filter', OpenListingsFilter.requests),
      ],
    );

    blocTest<OpenListingsCubit, OpenListingsState>(
      'avant le chargement, la bascule est sans effet et ne mesure rien',
      build: build,
      act: (c) => c.toggleExpanded(),
      expect: () => <OpenListingsState>[],
      verify: (_) => verifyNever(
        () => backend.capture(AnalyticsEvents.openListingsToggled, any()),
      ),
    );
  });

  group('trackOpened', () {
    test('mesure le type de carte ouverte, jamais son identifiant', () async {
      build().trackOpened('request');
      await Future<void>.delayed(Duration.zero);

      verify(
        () => backend.capture(AnalyticsEvents.openListingOpened, {
          'kind': 'request',
        }),
      ).called(1);
    });
  });
}
