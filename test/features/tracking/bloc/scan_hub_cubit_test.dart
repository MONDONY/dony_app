import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:dony/features/tracking/data/models/trip_scan_history_entry_model.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncementRepo extends Mock implements AnnouncementRepository {}

class _MockBidRepo extends Mock implements BidRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockTrackingRepo extends Mock implements TrackingRepository {}

BidModel _bid(String id, String status) => BidModel(
  id: id,
  announcementId: 'a',
  senderId: 's',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

AnnouncementModel _trip(String id, String status, [DateTime? date]) =>
    AnnouncementModel(
      id: id,
      travelerId: 'traveler-1',
      status: status,
      departureDate: date ?? DateTime(2026, 6, 10),
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      availableKg: 10,
      totalKg: 20,
      pricePerKg: 5,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  late _MockAnnouncementRepo annRepo;
  late _MockBidRepo bidRepo;
  late _MockAnalytics analytics;
  late _MockTrackingRepo trackingRepo;

  setUp(() {
    annRepo = _MockAnnouncementRepo();
    bidRepo = _MockBidRepo();
    analytics = _MockAnalytics();
    trackingRepo = _MockTrackingRepo();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  blocTest<ScanHubCubit, ScanHubState>(
    'aucun trajet → ScanHubEmpty',
    build: () {
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async => (announcements: <AnnouncementModel>[], totalElements: 0),
      );
      return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
    },
    act: (c) => c.load(),
    expect: () => [isA<ScanHubLoading>(), isA<ScanHubEmpty>()],
  );

  blocTest<ScanHubCubit, ScanHubState>(
    'un trajet IN_PROGRESS → ScanHubLoaded avec ce trajet sélectionné',
    build: () {
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async =>
            (announcements: [_trip('a', 'IN_PROGRESS')], totalElements: 1),
      );
      when(
        () => bidRepo.getBidsForAnnouncement('a'),
      ).thenAnswer((_) async => []);
      when(
        () => trackingRepo.getTripScanHistory('a'),
      ).thenAnswer((_) async => []);
      return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
    },
    act: (c) => c.load(),
    expect: () => [
      isA<ScanHubLoading>(),
      isA<ScanHubLoaded>()
          .having((s) => s.trips.map((t) => t.id), 'trips', ['a'])
          .having((s) => s.selectedTripId, 'selectedTripId', 'a'),
    ],
  );

  blocTest<ScanHubCubit, ScanHubState>(
    'deux trajets actifs → trips contient les deux, le plus proche sélectionné',
    build: () {
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async => (
          announcements: [
            _trip('later', 'IN_PROGRESS', DateTime(2026, 7)),
            _trip('soonest', 'IN_PROGRESS', DateTime(2026, 6)),
          ],
          totalElements: 2,
        ),
      );
      when(
        () => bidRepo.getBidsForAnnouncement(any()),
      ).thenAnswer((_) async => []);
      when(
        () => trackingRepo.getTripScanHistory('soonest'),
      ).thenAnswer((_) async => []);
      return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
    },
    act: (c) => c.load(),
    expect: () => [
      isA<ScanHubLoading>(),
      isA<ScanHubLoaded>()
          .having((s) => s.trips.map((t) => t.id), 'trips', [
            'soonest',
            'later',
          ])
          .having((s) => s.selectedTripId, 'selectedTripId', 'soonest'),
    ],
  );

  blocTest<ScanHubCubit, ScanHubState>(
    'erreur réseau → ScanHubError',
    build: () {
      when(
        () => annRepo.getMyAnnouncements(),
      ).thenThrow(Exception('Network error'));
      return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
    },
    act: (c) => c.load(),
    expect: () => [isA<ScanHubLoading>(), isA<ScanHubError>()],
  );

  blocTest<ScanHubCubit, ScanHubState>(
    'DioException du back → ScanHubError porte l\'AppException typée, pas un toString()',
    build: () {
      final options = RequestOptions(path: '/announcements/mine');
      when(() => annRepo.getMyAnnouncements()).thenThrow(
        DioException(
          requestOptions: options,
          error: const ForbiddenException('Accès refusé', 'forbidden'),
          response: Response(requestOptions: options, statusCode: 403),
        ),
      );
      return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
    },
    act: (c) => c.load(),
    expect: () => [
      isA<ScanHubLoading>(),
      isA<ScanHubError>().having(
        (s) => s.error,
        'error',
        isA<ForbiddenException>().having((e) => e.code, 'code', 'forbidden'),
      ),
    ],
  );

  blocTest<ScanHubCubit, ScanHubState>(
    'trajet ACTIVE sans bids → ScanHubLoaded avec compteurs à zéro',
    build: () {
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async => (announcements: [_trip('b', 'ACTIVE')], totalElements: 1),
      );
      when(
        () => bidRepo.getBidsForAnnouncement('b'),
      ).thenAnswer((_) async => []);
      when(
        () => trackingRepo.getTripScanHistory('b'),
      ).thenAnswer((_) async => []);
      return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
    },
    act: (c) => c.load(),
    expect: () => [
      isA<ScanHubLoading>(),
      isA<ScanHubLoaded>().having(
        (s) => s.progress.confirmedColis,
        'confirmedColis',
        0,
      ),
    ],
  );

  group('selectTrip', () {
    blocTest<ScanHubCubit, ScanHubState>(
      'change selectedTripId immédiatement, puis met à jour scanHistory',
      build: () {
        when(() => annRepo.getMyAnnouncements()).thenAnswer(
          (_) async => (
            announcements: [
              _trip('soonest', 'IN_PROGRESS', DateTime(2026, 6)),
              _trip('later', 'IN_PROGRESS', DateTime(2026, 7)),
            ],
            totalElements: 2,
          ),
        );
        when(
          () => bidRepo.getBidsForAnnouncement(any()),
        ).thenAnswer((_) async => []);
        when(
          () => trackingRepo.getTripScanHistory('soonest'),
        ).thenAnswer((_) async => []);
        when(() => trackingRepo.getTripScanHistory('later')).thenAnswer(
          (_) async => [
            TripScanHistoryEntryModel(
              donNumber: 'TRK000002',
              recipientName: 'Moussa Diop',
              eventType: 'DEPART',
              scannedAt: DateTime(2026, 6, 20, 14),
            ),
          ],
        );
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) async {
        await c.load();
        await c.selectTrip('later');
      },
      skip: 2, // ScanHubLoading + the initial ScanHubLoaded from load()
      expect: () => [
        isA<ScanHubLoaded>()
            .having((s) => s.selectedTripId, 'selectedTripId', 'later')
            .having((s) => s.scanHistory, 'scanHistory', isEmpty),
        isA<ScanHubLoaded>()
            .having((s) => s.selectedTripId, 'selectedTripId', 'later')
            .having((s) => s.scanHistory, 'scanHistory', hasLength(1)),
      ],
    );

    blocTest<ScanHubCubit, ScanHubState>(
      'même trajet déjà sélectionné → aucun nouvel état',
      build: () {
        when(() => annRepo.getMyAnnouncements()).thenAnswer(
          (_) async =>
              (announcements: [_trip('a', 'IN_PROGRESS')], totalElements: 1),
        );
        when(
          () => bidRepo.getBidsForAnnouncement('a'),
        ).thenAnswer((_) async => []);
        when(
          () => trackingRepo.getTripScanHistory('a'),
        ).thenAnswer((_) async => []);
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) async {
        await c.load();
        await c.selectTrip('a');
      },
      skip: 2,
      expect: () => [],
    );

    final staleCompleter = Completer<List<TripScanHistoryEntryModel>>();

    blocTest<ScanHubCubit, ScanHubState>(
      'fetch lent d\'un ancien trajet (stale) ne doit pas écraser le trajet sélectionné entre-temps',
      build: () {
        // 'later' est trips.first (soonest = 'soonest' avec date antérieure ?
        // non — selectScannableTrips trie par date croissante, donc 'soonest'
        // (2026-06-01) passe avant 'later' (2026-07-01) : load() sélectionne
        // et fetch déjà l'historique de 'soonest' de façon synchrone/normale.
        // On gate le fetch de 'later' (pas trips.first, jamais touché par
        // load()) derrière un Completer pour simuler un réseau lent : on le
        // sélectionne en premier (sans attendre), puis on bascule sur
        // 'soonest' avant que 'later' ne réponde — le garde-fou de
        // selectTrip doit alors ignorer la réponse tardive de 'later'.
        when(() => annRepo.getMyAnnouncements()).thenAnswer(
          (_) async => (
            announcements: [
              _trip('later', 'IN_PROGRESS', DateTime(2026, 7)),
              _trip('soonest', 'IN_PROGRESS', DateTime(2026, 6)),
            ],
            totalElements: 2,
          ),
        );
        when(
          () => bidRepo.getBidsForAnnouncement(any()),
        ).thenAnswer((_) async => []);
        when(() => trackingRepo.getTripScanHistory('soonest')).thenAnswer(
          (_) async => [
            TripScanHistoryEntryModel(
              donNumber: 'TRK-SOONEST',
              recipientName: 'Aissatou Diallo',
              eventType: 'DEPART',
              scannedAt: DateTime(2026, 6, 5, 9),
            ),
          ],
        );
        when(
          () => trackingRepo.getTripScanHistory('later'),
        ).thenAnswer((_) => staleCompleter.future);
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) async {
        await c
            .load(); // selectedTripId == 'soonest', scanHistory == [TRK-SOONEST]
        unawaited(
          c.selectTrip('later'),
        ); // fetch gated on staleCompleter — never resolves yet
        await c.selectTrip('soonest'); // switches back before 'later' responds
        staleCompleter.complete([
          TripScanHistoryEntryModel(
            donNumber: 'TRK-LATE-SHOULD-NOT-LAND',
            recipientName: 'Should Not Land',
            eventType: 'DEPART',
            scannedAt: DateTime(2026, 7, 2, 9),
          ),
        ]);
        await Future<void>.delayed(Duration.zero);
      },
      skip: 2, // ScanHubLoading + the initial ScanHubLoaded from load()
      expect: () => [
        isA<ScanHubLoaded>()
            .having((s) => s.selectedTripId, 'selectedTripId', 'later')
            .having((s) => s.scanHistory, 'scanHistory', isEmpty),
        isA<ScanHubLoaded>()
            .having((s) => s.selectedTripId, 'selectedTripId', 'soonest')
            .having((s) => s.scanHistory, 'scanHistory', isEmpty),
        isA<ScanHubLoaded>()
            .having((s) => s.selectedTripId, 'selectedTripId', 'soonest')
            .having((s) => s.scanHistory, 'scanHistory', hasLength(1))
            .having(
              (s) => s.scanHistory.first.donNumber,
              'donNumber',
              'TRK-SOONEST',
            ),
      ],
    );

    blocTest<ScanHubCubit, ScanHubState>(
      'erreur réseau sur getTripScanHistory → historique optimiste vide conservé, pas de ScanHubError',
      build: () {
        when(() => annRepo.getMyAnnouncements()).thenAnswer(
          (_) async => (
            announcements: [
              _trip('soonest', 'IN_PROGRESS', DateTime(2026, 6)),
              _trip('later', 'IN_PROGRESS', DateTime(2026, 7)),
            ],
            totalElements: 2,
          ),
        );
        when(
          () => bidRepo.getBidsForAnnouncement(any()),
        ).thenAnswer((_) async => []);
        when(
          () => trackingRepo.getTripScanHistory('soonest'),
        ).thenAnswer((_) async => []);
        when(
          () => trackingRepo.getTripScanHistory('later'),
        ).thenThrow(Exception('History fetch failed'));
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) async {
        await c.load();
        await c.selectTrip('later');
      },
      skip: 2, // ScanHubLoading + the initial ScanHubLoaded from load()
      expect: () => [
        isA<ScanHubLoaded>()
            .having((s) => s.selectedTripId, 'selectedTripId', 'later')
            .having((s) => s.scanHistory, 'scanHistory', isEmpty),
      ],
    );
  });

  blocTest<ScanHubCubit, ScanHubState>(
    'selectedTripBids exclut PENDING/REJECTED, garde ACCEPTED/HANDED_OVER',
    build: () {
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async =>
            (announcements: [_trip('a', 'IN_PROGRESS')], totalElements: 1),
      );
      when(() => bidRepo.getBidsForAnnouncement('a')).thenAnswer(
        (_) async => [
          _bid('pending', 'PENDING'),
          _bid('rejected', 'REJECTED'),
          _bid('accepted', 'ACCEPTED'),
          _bid('handed-over', 'HANDED_OVER'),
        ],
      );
      when(
        () => trackingRepo.getTripScanHistory('a'),
      ).thenAnswer((_) async => []);
      return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
    },
    act: (c) => c.load(),
    expect: () => [
      isA<ScanHubLoading>(),
      isA<ScanHubLoaded>().having(
        (s) => s.selectedTripBids.map((b) => b.id).toSet(),
        'selectedTripBids ids',
        {'accepted', 'handed-over'},
      ),
    ],
  );

  blocTest<ScanHubCubit, ScanHubState>(
    'erreur bidRepo.getBidsForAnnouncement → ScanHubError',
    build: () {
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async =>
            (announcements: [_trip('a', 'IN_PROGRESS')], totalElements: 1),
      );
      when(
        () => bidRepo.getBidsForAnnouncement('a'),
      ).thenThrow(Exception('Bid fetch failed'));
      return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
    },
    act: (c) => c.load(),
    expect: () => [isA<ScanHubLoading>(), isA<ScanHubError>()],
  );

  group('load(silent: true)', () {
    void twoTrips() {
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async => (
          announcements: [
            _trip('soonest', 'IN_PROGRESS', DateTime(2026, 6)),
            _trip('later', 'IN_PROGRESS', DateTime(2026, 7)),
          ],
          totalElements: 2,
        ),
      );
      when(
        () => bidRepo.getBidsForAnnouncement(any()),
      ).thenAnswer((_) async => [_bid('b1', 'ACCEPTED')]);
      when(
        () => trackingRepo.getTripScanHistory(any()),
      ).thenAnswer((_) async => []);
    }

    blocTest<ScanHubCubit, ScanHubState>(
      'garde le trajet sélectionné et n\'émet pas de chargement',
      build: () {
        twoTrips();
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) async {
        await c.load();
        await c.selectTrip('later');
        await c.load(silent: true);
      },
      skip: 4, // Loading, Loaded, bascule, historique
      expect: () => [
        isA<ScanHubLoaded>().having(
          (s) => s.selectedTripId,
          'selectedTripId',
          'later',
        ),
      ],
    );

    blocTest<ScanHubCubit, ScanHubState>(
      'un échec garde les données déjà affichées',
      build: () {
        twoTrips();
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) async {
        await c.load();
        when(
          () => annRepo.getMyAnnouncements(),
        ).thenThrow(Exception('offline'));
        await c.load(silent: true);
      },
      skip: 2,
      expect: () => <ScanHubState>[],
    );

    blocTest<ScanHubCubit, ScanHubState>(
      'sans données affichées, se comporte comme un chargement normal',
      build: () {
        twoTrips();
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) => c.load(silent: true),
      expect: () => [isA<ScanHubLoading>(), isA<ScanHubLoaded>()],
    );
  });

  test('selectTrip trace suivi_trip_changed avec sa source', () async {
    when(() => annRepo.getMyAnnouncements()).thenAnswer(
      (_) async => (
        announcements: [
          _trip('soonest', 'IN_PROGRESS', DateTime(2026, 6)),
          _trip('later', 'ACTIVE', DateTime(2026, 7)),
        ],
        totalElements: 2,
      ),
    );
    when(
      () => bidRepo.getBidsForAnnouncement(any()),
    ).thenAnswer((_) async => []);
    when(
      () => trackingRepo.getTripScanHistory(any()),
    ).thenAnswer((_) async => []);
    final cubit = ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
    await cubit.load();
    await cubit.selectTrip('later', source: 'other_trip');
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.suiviTripChanged,
        properties: {'source': 'other_trip'},
      ),
    ).called(1);
    await cubit.close();
  });

  test('hasParcelToValidate regarde tous les trajets', () {
    final loaded = ScanHubLoaded(
      trips: [_trip('a', 'IN_PROGRESS'), _trip('b', 'ACTIVE')],
      selectedTripId: 'a',
      bidsByTrip: {
        'a': [_bid('done', 'COMPLETED')],
        'b': [_bid('todo', 'ACCEPTED'), _bid('pending', 'PENDING')],
      },
      scanHistory: const [],
    );
    expect(loaded.hasParcelToValidate, isTrue);
    expect(loaded.confirmedBidsOf('b').map((b) => b.id), ['todo']);

    final allDone = ScanHubLoaded(
      trips: [_trip('a', 'IN_PROGRESS')],
      selectedTripId: 'a',
      bidsByTrip: {
        'a': [_bid('done', 'COMPLETED')],
      },
      scanHistory: const [],
    );
    expect(allDone.hasParcelToValidate, isFalse);
  });
}
