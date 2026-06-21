import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/package_request/bloc/trip_matching_bloc.dart';
import 'package:dony/features/package_request/data/models/matching_request.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements PackageRequestRepository {}

class MockAnalytics extends Mock implements AnalyticsService {}

MatchingRequestModel _match(String id, {int score = 50}) =>
    MatchingRequestModel(
      id: id,
      tripId: 't-$id',
      tripCorridor: 'Paris → Bamako',
      tripDepartureDate: DateTime(2026, 7, 10),
      tripAvailableKg: 10,
      senderId: 's-$id',
      senderName: 'Sender $id',
      senderInitials: 'S$id',
      senderRating: 4.5,
      senderTotalSent: 3,
      weightKg: 2,
      matchScore: score,
      requestedAt: DateTime(2026, 6, 19),
    );

void main() {
  late MockRepo repo;
  late MockAnalytics analytics;

  setUp(() {
    repo = MockRepo();
    analytics = MockAnalytics();
    when(() => analytics.logEvent(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});
    when(() => repo.getPackageMatchAlert()).thenAnswer((_) async => true);
    when(() => repo.setPackageMatchAlert(any())).thenAnswer((_) async {});
  });

  blocTest<TripMatchingBloc, TripMatchingState>(
    'TripMatchingRequested → loading then loaded with results',
    build: () {
      when(() => repo.findMatchingRequests())
          .thenAnswer((_) async => [_match('a', score: 90), _match('b')]);
      return TripMatchingBloc(repo, analytics);
    },
    act: (b) => b.add(const TripMatchingRequested()),
    expect: () => [
      isA<TripMatchingState>()
          .having((s) => s.status, 'status', TripMatchingStatus.loading),
      isA<TripMatchingState>()
          .having((s) => s.status, 'status', TripMatchingStatus.loaded)
          .having((s) => s.matches.length, 'len', 2),
    ],
  );

  blocTest<TripMatchingBloc, TripMatchingState>(
    'empty result → loaded with empty list',
    build: () {
      when(() => repo.findMatchingRequests()).thenAnswer((_) async => []);
      return TripMatchingBloc(repo, analytics);
    },
    act: (b) => b.add(const TripMatchingRequested()),
    expect: () => [
      isA<TripMatchingState>()
          .having((s) => s.status, 'status', TripMatchingStatus.loading),
      isA<TripMatchingState>()
          .having((s) => s.status, 'status', TripMatchingStatus.loaded)
          .having((s) => s.matches, 'matches', isEmpty),
    ],
  );

  blocTest<TripMatchingBloc, TripMatchingState>(
    'error path → status error with message',
    build: () {
      when(() => repo.findMatchingRequests())
          .thenThrow(Exception('boom'));
      return TripMatchingBloc(repo, analytics);
    },
    act: (b) => b.add(const TripMatchingRequested()),
    expect: () => [
      isA<TripMatchingState>()
          .having((s) => s.status, 'status', TripMatchingStatus.loading),
      isA<TripMatchingState>()
          .having((s) => s.status, 'status', TripMatchingStatus.error)
          .having((s) => s.errorMessage, 'err', isNotNull),
    ],
  );

  blocTest<TripMatchingBloc, TripMatchingState>(
    'TripMatchingRefreshRequested reloads results',
    build: () {
      when(() => repo.findMatchingRequests())
          .thenAnswer((_) async => [_match('a')]);
      return TripMatchingBloc(repo, analytics);
    },
    act: (b) => b.add(const TripMatchingRefreshRequested()),
    expect: () => [
      isA<TripMatchingState>()
          .having((s) => s.status, 'status', TripMatchingStatus.loading),
      isA<TripMatchingState>()
          .having((s) => s.status, 'status', TripMatchingStatus.loaded)
          .having((s) => s.matches.length, 'len', 1),
    ],
  );

  blocTest<TripMatchingBloc, TripMatchingState>(
    'load also fetches the bell (alertEnabled) state',
    build: () {
      when(() => repo.findMatchingRequests()).thenAnswer((_) async => []);
      when(() => repo.getPackageMatchAlert()).thenAnswer((_) async => false);
      return TripMatchingBloc(repo, analytics);
    },
    act: (b) => b.add(const TripMatchingRequested()),
    expect: () => [
      isA<TripMatchingState>()
          .having((s) => s.status, 'status', TripMatchingStatus.loading),
      isA<TripMatchingState>()
          .having((s) => s.status, 'status', TripMatchingStatus.loaded)
          .having((s) => s.alertEnabled, 'alertEnabled', false),
    ],
  );

  blocTest<TripMatchingBloc, TripMatchingState>(
    'load tolerates a bell fetch failure (alertEnabled stays null)',
    build: () {
      when(() => repo.findMatchingRequests()).thenAnswer((_) async => []);
      when(() => repo.getPackageMatchAlert()).thenThrow(Exception('net'));
      return TripMatchingBloc(repo, analytics);
    },
    act: (b) => b.add(const TripMatchingRequested()),
    expect: () => [
      isA<TripMatchingState>()
          .having((s) => s.status, 'status', TripMatchingStatus.loading),
      isA<TripMatchingState>()
          .having((s) => s.status, 'status', TripMatchingStatus.loaded)
          .having((s) => s.alertEnabled, 'alertEnabled', isNull),
    ],
  );

  blocTest<TripMatchingBloc, TripMatchingState>(
    'TripMatchingAlertToggled persists the new value optimistically',
    build: () => TripMatchingBloc(repo, analytics),
    seed: () => const TripMatchingState(
        status: TripMatchingStatus.loaded, alertEnabled: true),
    act: (b) => b.add(const TripMatchingAlertToggled(false)),
    expect: () => [
      isA<TripMatchingState>()
          .having((s) => s.alertEnabled, 'alertEnabled', false),
    ],
    verify: (_) {
      verify(() => repo.setPackageMatchAlert(false)).called(1);
    },
  );

  blocTest<TripMatchingBloc, TripMatchingState>(
    'TripMatchingAlertToggled reverts when the API call fails',
    build: () {
      when(() => repo.setPackageMatchAlert(any())).thenThrow(Exception('net'));
      return TripMatchingBloc(repo, analytics);
    },
    seed: () => const TripMatchingState(
        status: TripMatchingStatus.loaded, alertEnabled: true),
    act: (b) => b.add(const TripMatchingAlertToggled(false)),
    expect: () => [
      isA<TripMatchingState>()
          .having((s) => s.alertEnabled, 'optimistic', false),
      isA<TripMatchingState>()
          .having((s) => s.alertEnabled, 'reverted', true),
    ],
  );
}
