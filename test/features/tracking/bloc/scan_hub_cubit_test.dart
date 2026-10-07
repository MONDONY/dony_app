import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/trip_arrival_events_service.dart';
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

  group('load(preferredTripId) — ouvert depuis un colis (FLUTTER-9N)', () {
    void stubTwoTrips() {
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
        () => trackingRepo.getTripScanHistory(any()),
      ).thenAnswer((_) async => []);
    }

    blocTest<ScanHubCubit, ScanHubState>(
      'le trajet du colis prime sur la sélection automatique, et le reste',
      build: () {
        stubTwoTrips();
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) async {
        await c.load(preferredTripId: 'later');
        await c.load(silent: true);
      },
      expect: () => [
        isA<ScanHubLoading>(),
        isA<ScanHubLoaded>().having(
          (s) => s.selectedTripId,
          'selectedTripId',
          'later',
        ),
        isA<ScanHubLoaded>().having(
          (s) => s.selectedTripId,
          'selectedTripId',
          'later',
        ),
      ],
    );

    blocTest<ScanHubCubit, ScanHubState>(
      'trajet du colis non scannable → sélection automatique',
      build: () {
        stubTwoTrips();
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) => c.load(preferredTripId: 'gone'),
      expect: () => [
        isA<ScanHubLoading>(),
        isA<ScanHubLoaded>().having(
          (s) => s.selectedTripId,
          'selectedTripId',
          'soonest',
        ),
      ],
    );
  });

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
    'trajet ACTIVE sans bids → ScanHubLoaded sans colis',
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
        (s) => s.selectedTripBids,
        'selectedTripBids',
        isEmpty,
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

    // Recette Redmi : onglet ouvert avant le premier trajet, gardé vivant
    // par le shell. Le retour sur l'onglet doit faire apparaître les colis.
    blocTest<ScanHubCubit, ScanHubState>(
      'depuis « Rien à valider » : colis affichés sans chargement',
      build: () {
        when(() => annRepo.getMyAnnouncements()).thenAnswer(
          (_) async => (announcements: <AnnouncementModel>[], totalElements: 0),
        );
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) async {
        await c.load();
        twoTrips();
        await c.load(silent: true);
      },
      skip: 2,
      expect: () => [isA<ScanHubLoaded>()],
    );

    blocTest<ScanHubCubit, ScanHubState>(
      'depuis « Rien à valider », un échec s\'affiche en erreur',
      build: () {
        when(() => annRepo.getMyAnnouncements()).thenAnswer(
          (_) async => (announcements: <AnnouncementModel>[], totalElements: 0),
        );
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
      expect: () => [isA<ScanHubError>()],
    );

    test('deux rechargements silencieux simultanés : un seul appel', () async {
      twoTrips();
      final cubit = ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      await cubit.load();
      clearInteractions(annRepo);
      await Future.wait([cubit.load(silent: true), cubit.load(silent: true)]);
      verify(() => annRepo.getMyAnnouncements()).called(1);
      await cubit.load(silent: true);
      verify(() => annRepo.getMyAnnouncements()).called(1);
      await cubit.close();
    });

    test('résultat arrivé après la fermeture : ignoré', () async {
      final pending =
          Completer<
            ({List<AnnouncementModel> announcements, int totalElements})
          >();
      when(
        () => annRepo.getMyAnnouncements(),
      ).thenAnswer((_) => pending.future);
      final cubit = ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      final loading = cubit.load();
      await cubit.close();
      pending.complete((
        announcements: <AnnouncementModel>[],
        totalElements: 0,
      ));
      await loading;
      expect(cubit.state, isA<ScanHubLoading>());
    });
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

  group('trajet affiché : sélection automatique et choix du voyageur', () {
    /// `soonest` (en cours) n'a que des colis remis, `later` (à venir) un
    /// colis à récupérer, `third` (à venir) un colis à récupérer aussi.
    void tripsWithWork({bool withThird = true, bool laterStillThere = true}) {
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async => (
          announcements: [
            _trip('soonest', 'IN_PROGRESS', DateTime(2026, 6)),
            if (laterStillThere) _trip('later', 'ACTIVE', DateTime(2026, 7)),
            if (withThird) _trip('third', 'ACTIVE', DateTime(2026, 8)),
          ],
          totalElements: 3,
        ),
      );
      when(
        () => bidRepo.getBidsForAnnouncement('soonest'),
      ).thenAnswer((_) async => [_bid('done', 'COMPLETED')]);
      when(
        () => bidRepo.getBidsForAnnouncement('later'),
      ).thenAnswer((_) async => [_bid('todo', 'ACCEPTED')]);
      when(
        () => bidRepo.getBidsForAnnouncement('third'),
      ).thenAnswer((_) async => [_bid('todo-3', 'ACCEPTED')]);
      when(
        () => trackingRepo.getTripScanHistory(any()),
      ).thenAnswer((_) async => []);
    }

    blocTest<ScanHubCubit, ScanHubState>(
      'par défaut : le premier trajet qui a un colis à valider',
      build: () {
        tripsWithWork();
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) => c.load(),
      expect: () => [
        isA<ScanHubLoading>(),
        isA<ScanHubLoaded>().having(
          (s) => s.selectedTripId,
          'selectedTripId',
          'later',
        ),
      ],
    );

    blocTest<ScanHubCubit, ScanHubState>(
      'rien à valider nulle part : le premier trajet',
      build: () {
        when(() => annRepo.getMyAnnouncements()).thenAnswer(
          (_) async => (
            announcements: [
              _trip('later', 'ACTIVE', DateTime(2026, 7)),
              _trip('soonest', 'IN_PROGRESS', DateTime(2026, 6)),
            ],
            totalElements: 2,
          ),
        );
        when(
          () => bidRepo.getBidsForAnnouncement(any()),
        ).thenAnswer((_) async => [_bid('done', 'COMPLETED')]);
        when(
          () => trackingRepo.getTripScanHistory(any()),
        ).thenAnswer((_) async => []);
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) => c.load(),
      expect: () => [
        isA<ScanHubLoading>(),
        isA<ScanHubLoaded>().having(
          (s) => s.selectedTripId,
          'selectedTripId',
          'soonest',
        ),
      ],
    );

    blocTest<ScanHubCubit, ScanHubState>(
      'sans choix du voyageur, un rechargement réapplique la règle',
      build: () {
        tripsWithWork();
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) async {
        await c.load();
        // Le colis de `later` vient d'être remis : `third` passe devant.
        when(
          () => bidRepo.getBidsForAnnouncement('later'),
        ).thenAnswer((_) async => [_bid('todo', 'COMPLETED')]);
        await c.load(silent: true);
      },
      skip: 2,
      expect: () => [
        isA<ScanHubLoaded>().having(
          (s) => s.selectedTripId,
          'selectedTripId',
          'third',
        ),
      ],
    );

    blocTest<ScanHubCubit, ScanHubState>(
      'le trajet choisi dans la liste prime sur la règle au rechargement',
      build: () {
        tripsWithWork();
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) async {
        await c.load();
        await c.selectTrip('soonest');
        await c.load(silent: true);
      },
      skip: 4, // Loading, Loaded, bascule, historique
      expect: () => [
        isA<ScanHubLoaded>().having(
          (s) => s.selectedTripId,
          'selectedTripId',
          'soonest',
        ),
      ],
    );

    blocTest<ScanHubCubit, ScanHubState>(
      'confirmer le trajet déjà affiché compte comme un choix',
      build: () {
        tripsWithWork();
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) async {
        await c.load();
        await c.selectTrip('later');
        when(
          () => bidRepo.getBidsForAnnouncement('later'),
        ).thenAnswer((_) async => [_bid('todo', 'COMPLETED')]);
        await c.load(silent: true);
      },
      skip: 2,
      expect: () => [
        isA<ScanHubLoaded>().having(
          (s) => s.selectedTripId,
          'selectedTripId',
          'later',
        ),
      ],
      verify: (_) => verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.suiviTripChanged,
          properties: any(named: 'properties'),
        ),
      ),
    );

    blocTest<ScanHubCubit, ScanHubState>(
      '« Passer sur ce trajet » compte comme un choix du voyageur',
      build: () {
        tripsWithWork();
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) async {
        await c.load();
        await c.selectTrip('third', source: 'other_trip');
        await c.load(silent: true);
      },
      skip: 4,
      expect: () => [
        isA<ScanHubLoaded>().having(
          (s) => s.selectedTripId,
          'selectedTripId',
          'third',
        ),
      ],
    );

    blocTest<ScanHubCubit, ScanHubState>(
      'trajet choisi disparu : retour à la règle, choix oublié',
      build: () {
        tripsWithWork();
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) async {
        await c.load();
        await c.selectTrip('third');
        tripsWithWork(withThird: false);
        await c.load(silent: true);
        // `third` revient : le choix ne ressuscite pas.
        tripsWithWork();
        await c.load(silent: true);
      },
      skip: 4,
      expect: () => [
        isA<ScanHubLoaded>().having(
          (s) => s.selectedTripId,
          'selectedTripId',
          'later',
        ),
        isA<ScanHubLoaded>().having(
          (s) => s.selectedTripId,
          'selectedTripId',
          'later',
        ),
      ],
    );

    blocTest<ScanHubCubit, ScanHubState>(
      'trajet inconnu : ignoré',
      build: () {
        tripsWithWork();
        return ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      },
      act: (c) async {
        await c.load();
        await c.selectTrip('ghost');
      },
      skip: 2,
      expect: () => <ScanHubState>[],
    );

    test('choix gardé en mémoire seulement : un nouveau cubit repart de la '
        'règle', () async {
      tripsWithWork();
      final first = ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      await first.load();
      await first.selectTrip('soonest');
      await first.close();

      final restarted = ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo);
      await restarted.load();
      expect((restarted.state as ScanHubLoaded).selectedTripId, 'later');
      await restarted.close();
    });
  });

  test('toValidateCountOf compte les colis qui attendent une étape', () {
    final loaded = ScanHubLoaded(
      trips: [_trip('a', 'IN_PROGRESS')],
      selectedTripId: 'a',
      bidsByTrip: {
        'a': [
          _bid('todo', 'ACCEPTED'),
          _bid('road', 'IN_TRANSIT'),
          _bid('done', 'COMPLETED'),
          _bid('pending', 'PENDING'),
        ],
      },
      scanHistory: const [],
    );
    expect(loaded.toValidateCountOf('a'), 2);
    expect(loaded.toValidateCountOf('unknown'), 0);
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

  group('trajet marqué arrivé ailleurs (FLUTTER-D6)', () {
    test('relit les colis en silence : le transit disparaît', () async {
      var status = 'HANDED_OVER';
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async =>
            (announcements: [_trip('a', 'IN_PROGRESS')], totalElements: 1),
      );
      when(
        () => bidRepo.getBidsForAnnouncement('a'),
      ).thenAnswer((_) async => [_bid('b1', status)]);
      when(
        () => trackingRepo.getTripScanHistory('a'),
      ).thenAnswer((_) async => []);
      final events = TripArrivalEventsService();
      addTearDown(events.dispose);
      final cubit = ScanHubCubit(
        annRepo,
        bidRepo,
        analytics,
        trackingRepo,
        tripArrivalEvents: events,
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(
        (cubit.state as ScanHubLoaded).selectedTripBids.single.status,
        'HANDED_OVER',
      );

      status = 'ARRIVED';
      final states = <ScanHubState>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);
      events.notifyArrived('a');
      await pumpEventQueue();

      // Rechargement silencieux : pas d'état de chargement intermédiaire.
      expect(states.whereType<ScanHubLoading>(), isEmpty);
      expect(
        (cubit.state as ScanHubLoaded).selectedTripBids.single.status,
        'ARRIVED',
      );
    });

    test('cubit fermé → plus abonné au signal', () async {
      final events = TripArrivalEventsService();
      addTearDown(events.dispose);
      final cubit = ScanHubCubit(
        annRepo,
        bidRepo,
        analytics,
        trackingRepo,
        tripArrivalEvents: events,
      );
      await cubit.close();
      events.notifyArrived('a');
      await pumpEventQueue();
      verifyNever(() => annRepo.getMyAnnouncements());
    });
  });
}
