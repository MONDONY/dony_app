import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_matches_cubit.dart';
import 'package:dony/features/corridor_alerts/data/corridor_alert_repository.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_matches.dart';
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

void main() {
  late MockCorridorAlertRepository repo;
  late MockAnalyticsService analytics;

  setUp(() {
    repo = MockCorridorAlertRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  CorridorAlertMatchesCubit build({
    AlertDirection direction = AlertDirection.travelerWantsPackages,
  }) => CorridorAlertMatchesCubit(
    repo,
    analytics,
    alertId: 'alert-1',
    direction: direction,
  );

  blocTest<CorridorAlertMatchesCubit, CorridorAlertMatchesState>(
    'package direction loaded → result.packages populated',
    build: () => build(),
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
    expect: () => [
      isA<CorridorAlertMatchesState>().having(
        (s) => s.status,
        'status',
        CorridorAlertMatchesStatus.loading,
      ),
      isA<CorridorAlertMatchesState>()
          .having((s) => s.status, 'status', CorridorAlertMatchesStatus.loaded)
          .having((s) => s.result?.packages.length, 'packages', 1),
    ],
  );

  blocTest<CorridorAlertMatchesCubit, CorridorAlertMatchesState>(
    'trip direction loaded → result.trips populated',
    build: () => build(direction: AlertDirection.senderWantsTrips),
    setUp: () =>
        when(
          () => repo.getMatches('alert-1', AlertDirection.senderWantsTrips),
        ).thenAnswer(
          (_) async => CorridorAlertMatches(
            direction: AlertDirection.senderWantsTrips,
            trips: [_fakeTrip('ann-1')],
          ),
        ),
    act: (c) => c.load(),
    expect: () => [
      isA<CorridorAlertMatchesState>().having(
        (s) => s.status,
        'status',
        CorridorAlertMatchesStatus.loading,
      ),
      isA<CorridorAlertMatchesState>()
          .having((s) => s.status, 'status', CorridorAlertMatchesStatus.loaded)
          .having((s) => s.result?.trips.length, 'trips', 1),
    ],
  );

  blocTest<CorridorAlertMatchesCubit, CorridorAlertMatchesState>(
    'empty result → empty state',
    build: () => build(),
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
    ],
  );

  blocTest<CorridorAlertMatchesCubit, CorridorAlertMatchesState>(
    'load error → error state with message',
    build: () => build(),
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
  );
}
