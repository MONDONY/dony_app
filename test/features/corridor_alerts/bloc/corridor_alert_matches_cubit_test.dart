import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_matches_cubit.dart';
import 'package:dony/features/corridor_alerts/data/corridor_alert_repository.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_matches.dart';
import 'package:dony/features/package_request/data/models/matching_request.dart';
import 'package:dony/core/services/analytics_service.dart';
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

void main() {
  late MockCorridorAlertRepository repo;
  late MockAnalyticsService analytics;

  setUp(() {
    repo = MockCorridorAlertRepository();
    analytics = MockAnalyticsService();
    when(() => analytics.logEvent(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});
  });

  CorridorAlertMatchesCubit build() => CorridorAlertMatchesCubit(
        repo,
        analytics,
        alertId: 'alert-1',
        direction: AlertDirection.travelerWantsPackages,
      );

  blocTest<CorridorAlertMatchesCubit, CorridorAlertMatchesState>(
    'load success with matches → loaded state',
    build: build,
    setUp: () {
      when(() => repo.getMatches(
            'alert-1',
            AlertDirection.travelerWantsPackages,
          )).thenAnswer((_) async => CorridorAlertMatches(
            direction: AlertDirection.travelerWantsPackages,
            packages: [_fakeMatch('m1'), _fakeMatch('m2')],
          ));
    },
    act: (c) => c.load(),
    expect: () => [
      const CorridorAlertMatchesState(
          status: CorridorAlertMatchesStatus.loading),
      isA<CorridorAlertMatchesState>()
          .having((s) => s.status, 'status', CorridorAlertMatchesStatus.loaded)
          .having(
              (s) => s.matches.packages.length, 'packages length', 2),
    ],
  );

  blocTest<CorridorAlertMatchesCubit, CorridorAlertMatchesState>(
    'load empty → empty state',
    build: build,
    setUp: () {
      when(() => repo.getMatches(
            'alert-1',
            AlertDirection.travelerWantsPackages,
          )).thenAnswer((_) async => const CorridorAlertMatches(
            direction: AlertDirection.travelerWantsPackages,
          ));
    },
    act: (c) => c.load(),
    expect: () => [
      const CorridorAlertMatchesState(
          status: CorridorAlertMatchesStatus.loading),
      const CorridorAlertMatchesState(
          status: CorridorAlertMatchesStatus.empty),
    ],
  );

  blocTest<CorridorAlertMatchesCubit, CorridorAlertMatchesState>(
    'load error → error state with message',
    build: build,
    setUp: () {
      when(() => repo.getMatches(
            'alert-1',
            AlertDirection.travelerWantsPackages,
          )).thenThrow(Exception('network error'));
    },
    act: (c) => c.load(),
    expect: () => [
      const CorridorAlertMatchesState(
          status: CorridorAlertMatchesStatus.loading),
      isA<CorridorAlertMatchesState>()
          .having((s) => s.status, 'status', CorridorAlertMatchesStatus.error)
          .having((s) => s.errorMessage, 'errorMessage', isNotNull),
    ],
  );
}
