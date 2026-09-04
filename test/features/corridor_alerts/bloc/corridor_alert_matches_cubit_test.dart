import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_matches_cubit.dart';
import 'package:dony/features/corridor_alerts/data/corridor_alert_repository.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_matches.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/data/models/trip_match_model.dart';
import 'package:dony/features/package_request/data/models/matching_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCorridorAlertRepository extends Mock
    implements CorridorAlertRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

MatchingRequestModel _fakeMatch(String id) => MatchingRequestModel(
  id: id,
  senderId: 'sender-1',
  senderName: 'Jean D.',
  senderInitials: 'JD',
  senderRating: 4.5,
  senderTotalSent: 10,
  weightKg: 5.0,
  budgetPerKg: 10.0,
  matchScore: 85,
  requestedAt: DateTime(2026, 6, 20),
);

TripMatchModel _fakeTrip(String id) => TripMatchModel(
  announcementId: id,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 7, 10),
  travelerId: 't-1',
  travelerName: 'Awa S.',
  travelerInitials: 'AS',
  travelerRating: 4.7,
  availableKg: 12.0,
  pricePerKg: 9.5,
);

CorridorAlertModel _alert(AlertDirection direction, {int fresh = 2}) =>
    CorridorAlertModel(
      id: 'alert-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      active: true,
      matchCount: 3,
      newMatchCount: fresh,
      direction: direction,
      createdAt: DateTime(2026, 6, 20),
    );

void main() {
  late MockCorridorAlertRepository repo;
  late MockAnalyticsService analytics;

  setUp(() {
    repo = MockCorridorAlertRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    // Par défaut, marquer comme vu renvoie l'alerte à zéro nouveauté.
    when(() => repo.markSeen('alert-1')).thenAnswer(
      (_) async => _alert(AlertDirection.travelerWantsPackages, fresh: 0),
    );
  });

  CorridorAlertMatchesCubit build({CorridorAlertModel? alert}) =>
      CorridorAlertMatchesCubit(
        repo,
        analytics,
        alertId: 'alert-1',
        alert: alert,
      );

  blocTest<CorridorAlertMatchesCubit, CorridorAlertMatchesState>(
    'alerte fournie, direction colis → packages, puis marquée vue',
    build: () => build(alert: _alert(AlertDirection.travelerWantsPackages)),
    setUp: () =>
        when(
          () =>
              repo.getMatches('alert-1', AlertDirection.travelerWantsPackages),
        ).thenAnswer(
          (_) async => CorridorAlertMatches(
            direction: AlertDirection.travelerWantsPackages,
            packages: [_fakeMatch('m1')],
          ),
        ),
    act: (c) => c.load(),
    wait: const Duration(milliseconds: 20),
    expect: () => [
      isA<CorridorAlertMatchesState>().having(
        (s) => s.status,
        'status',
        CorridorAlertMatchesStatus.loading,
      ),
      isA<CorridorAlertMatchesState>()
          .having((s) => s.status, 'status', CorridorAlertMatchesStatus.loaded)
          .having((s) => s.result?.packages.length, 'packages', 1)
          .having((s) => s.alert?.newMatchCount, 'newMatchCount', 2),
      // La réponse de « vu » remet l'alerte à zéro sans toucher au résultat.
      isA<CorridorAlertMatchesState>()
          .having((s) => s.status, 'status', CorridorAlertMatchesStatus.loaded)
          .having((s) => s.alert?.newMatchCount, 'newMatchCount', 0)
          .having((s) => s.result?.packages.length, 'packages', 1),
    ],
    verify: (_) {
      verify(() => repo.markSeen('alert-1')).called(1);
      verifyNever(() => repo.getById(any()));
    },
  );

  blocTest<CorridorAlertMatchesCubit, CorridorAlertMatchesState>(
    'alerte absente (push) → chargée par id, direction trajets respectée',
    build: () => build(),
    setUp: () {
      when(
        () => repo.getById('alert-1'),
      ).thenAnswer((_) async => _alert(AlertDirection.senderWantsTrips));
      when(
        () => repo.getMatches('alert-1', AlertDirection.senderWantsTrips),
      ).thenAnswer(
        (_) async => CorridorAlertMatches(
          direction: AlertDirection.senderWantsTrips,
          trips: [_fakeTrip('ann-1')],
        ),
      );
      when(() => repo.markSeen('alert-1')).thenAnswer(
        (_) async => _alert(AlertDirection.senderWantsTrips, fresh: 0),
      );
    },
    act: (c) => c.load(),
    wait: const Duration(milliseconds: 20),
    expect: () => [
      isA<CorridorAlertMatchesState>().having(
        (s) => s.status,
        'status',
        CorridorAlertMatchesStatus.loading,
      ),
      isA<CorridorAlertMatchesState>()
          .having((s) => s.status, 'status', CorridorAlertMatchesStatus.loaded)
          .having(
            (s) => s.alert?.direction,
            'direction',
            AlertDirection.senderWantsTrips,
          )
          .having((s) => s.result?.trips.length, 'trips', 1),
      isA<CorridorAlertMatchesState>().having(
        (s) => s.alert?.newMatchCount,
        'newMatchCount',
        0,
      ),
    ],
    verify: (_) => verify(() => repo.getById('alert-1')).called(1),
  );

  group('seuil « déjà vu »', () {
    final seenAt = DateTime(2026, 9, 1, 8);

    test(
      'isNew : inconnu → rien de nouveau ; jamais vue → tout est nouveau',
      () {
        const unknown = CorridorAlertMatchesState();
        expect(unknown.isNew(DateTime(2026, 9, 3)), isFalse);

        const neverSeen = CorridorAlertMatchesState(thresholdKnown: true);
        expect(neverSeen.isNew(DateTime(2020)), isTrue);
        expect(neverSeen.isNew(null), isTrue);
      },
    );

    test('isNew : après le seuil seulement, jamais sans horodatage', () {
      final s = CorridorAlertMatchesState(
        thresholdKnown: true,
        seenThreshold: seenAt,
      );
      expect(s.isNew(DateTime(2026, 9, 2)), isTrue);
      expect(s.isNew(DateTime(2026, 8, 30)), isFalse);
      expect(s.isNew(seenAt), isFalse);
      expect(s.isNew(null), isFalse);
    });

    blocTest<CorridorAlertMatchesCubit, CorridorAlertMatchesState>(
      'le seuil est figé avant « vu » et survit à un rechargement',
      build: () => build(
        alert: CorridorAlertModel(
          id: 'alert-1',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          active: true,
          lastSeenAt: seenAt,
          createdAt: DateTime(2026, 6, 20),
        ),
      ),
      setUp: () {
        when(
          () =>
              repo.getMatches('alert-1', AlertDirection.travelerWantsPackages),
        ).thenAnswer(
          (_) async => CorridorAlertMatches(
            direction: AlertDirection.travelerWantsPackages,
            packages: [_fakeMatch('m1')],
          ),
        );
        // « Vu » renvoie une alerte dont lastSeenAt vient de passer à maintenant.
        when(() => repo.markSeen('alert-1')).thenAnswer(
          (_) async => CorridorAlertModel(
            id: 'alert-1',
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            active: true,
            lastSeenAt: DateTime(2026, 9, 4, 12),
            createdAt: DateTime(2026, 6, 20),
          ),
        );
      },
      act: (c) async {
        await c.load();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await c.load();
      },
      wait: const Duration(milliseconds: 20),
      verify: (c) {
        expect(c.state.thresholdKnown, isTrue);
        expect(c.state.seenThreshold, seenAt);
        expect(c.state.alert?.lastSeenAt, DateTime(2026, 9, 4, 12));
      },
    );
  });

  blocTest<CorridorAlertMatchesCubit, CorridorAlertMatchesState>(
    'résultat vide → empty, et marquée vue quand même',
    build: () => build(alert: _alert(AlertDirection.travelerWantsPackages)),
    setUp: () =>
        when(
          () =>
              repo.getMatches('alert-1', AlertDirection.travelerWantsPackages),
        ).thenAnswer(
          (_) async => const CorridorAlertMatches(
            direction: AlertDirection.travelerWantsPackages,
          ),
        ),
    act: (c) => c.load(),
    wait: const Duration(milliseconds: 20),
    expect: () => [
      isA<CorridorAlertMatchesState>().having(
        (s) => s.status,
        'status',
        CorridorAlertMatchesStatus.loading,
      ),
      isA<CorridorAlertMatchesState>().having(
        (s) => s.status,
        'status',
        CorridorAlertMatchesStatus.empty,
      ),
      isA<CorridorAlertMatchesState>()
          .having((s) => s.status, 'status', CorridorAlertMatchesStatus.empty)
          .having((s) => s.alert?.newMatchCount, 'newMatchCount', 0),
    ],
    verify: (_) => verify(() => repo.markSeen('alert-1')).called(1),
  );

  blocTest<CorridorAlertMatchesCubit, CorridorAlertMatchesState>(
    'échec silencieux de « vu » : l\'écran reste chargé',
    build: () => build(alert: _alert(AlertDirection.travelerWantsPackages)),
    setUp: () {
      when(
        () => repo.getMatches('alert-1', AlertDirection.travelerWantsPackages),
      ).thenAnswer(
        (_) async => CorridorAlertMatches(
          direction: AlertDirection.travelerWantsPackages,
          packages: [_fakeMatch('m1')],
        ),
      );
      when(() => repo.markSeen('alert-1')).thenThrow(Exception('offline'));
    },
    act: (c) => c.load(),
    wait: const Duration(milliseconds: 20),
    expect: () => [
      isA<CorridorAlertMatchesState>().having(
        (s) => s.status,
        'status',
        CorridorAlertMatchesStatus.loading,
      ),
      isA<CorridorAlertMatchesState>().having(
        (s) => s.status,
        'status',
        CorridorAlertMatchesStatus.loaded,
      ),
    ],
  );

  blocTest<CorridorAlertMatchesCubit, CorridorAlertMatchesState>(
    'load error → error state with message, rien n\'est marqué vu',
    build: () => build(alert: _alert(AlertDirection.travelerWantsPackages)),
    setUp: () {
      when(
        () => repo.getMatches('alert-1', AlertDirection.travelerWantsPackages),
      ).thenThrow(Exception('network error'));
    },
    act: (c) => c.load(),
    expect: () => [
      isA<CorridorAlertMatchesState>().having(
        (s) => s.status,
        'status',
        CorridorAlertMatchesStatus.loading,
      ),
      isA<CorridorAlertMatchesState>()
          .having((s) => s.status, 'status', CorridorAlertMatchesStatus.error)
          .having((s) => s.errorMessage, 'errorMessage', isNotNull),
    ],
    verify: (_) => verifyNever(() => repo.markSeen(any())),
  );
}
