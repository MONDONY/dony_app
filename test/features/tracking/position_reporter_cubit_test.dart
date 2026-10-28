import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/tracking/bloc/position_reporter_cubit.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:dony/features/tracking/data/trip_tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncements extends Mock implements AnnouncementRepository {}

class _MockTracking extends Mock implements TripTrackingRepository {}

class _MockLocator extends Mock implements ScanLocator {}

class _MockAnalytics extends Mock implements AnalyticsService {}

AnnouncementModel _trip(String id, {bool active = false}) => AnnouncementModel(
  id: id,
  travelerId: 't',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 11),
  availableKg: 10,
  totalKg: 20,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
  trackingActive: active,
);

void main() {
  late _MockAnnouncements announcements;
  late _MockTracking tracking;
  late _MockLocator locator;
  late _MockAnalytics analytics;
  late DateTime clock;
  late bool session;

  PositionReporterCubit build() => PositionReporterCubit(
    announcements: announcements,
    tracking: tracking,
    locator: locator,
    analytics: analytics,
    hasRealSession: () => session,
    now: () => clock,
  );

  void trips(List<AnnouncementModel> list) {
    when(() => announcements.getMyAnnouncements()).thenAnswer(
      (_) async => (announcements: list, totalElements: list.length),
    );
  }

  setUp(() {
    announcements = _MockAnnouncements();
    tracking = _MockTracking();
    locator = _MockLocator();
    analytics = _MockAnalytics();
    clock = DateTime(2026, 11, 1, 10);
    session = true;
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => locator.isPermissionGranted()).thenAnswer((_) async => true);
    when(
      () => locator.captureCoordinatesIfGranted(),
    ).thenAnswer((_) async => const ScanPosition(lat: 48.85, lon: 2.35));
    when(
      () => tracking.sendPosition(any(), any(), any()),
    ).thenAnswer((_) async {});
  });

  void verifySkipped(String reason) => verify(
    () => analytics.logEvent(
      AnalyticsEvents.tripPositionSkipped,
      properties: {'reason': reason},
    ),
  ).called(1);

  blocTest<PositionReporterCubit, PositionReporterState>(
    'doesNothingWithoutTrackingActiveTrip',
    build: build,
    setUp: () => trips([_trip('a'), _trip('b')]),
    act: (c) => c.onResume(),
    verify: (_) {
      verifyNever(() => tracking.sendPosition(any(), any(), any()));
      verifyNever(() => locator.captureCoordinatesIfGranted());
      verifySkipped('no_active_trip');
    },
  );

  blocTest<PositionReporterCubit, PositionReporterState>(
    'sendsOnceWhenActiveAndPermissionGranted',
    build: build,
    setUp: () => trips([_trip('a'), _trip('b', active: true)]),
    act: (c) => c.onResume(),
    verify: (_) {
      verify(() => tracking.sendPosition('b', 48.85, 2.35)).called(1);
      verifyNever(() => tracking.sendPosition('a', any(), any()));
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.tripPositionSent,
          properties: {'source': 'resume'},
        ),
      ).called(1);
    },
  );

  blocTest<PositionReporterCubit, PositionReporterState>(
    'doesNotAskPermissionOnResume',
    build: build,
    setUp: () {
      trips([_trip('a', active: true)]);
      when(() => locator.isPermissionGranted()).thenAnswer((_) async => false);
    },
    act: (c) => c.onResume(),
    verify: (_) {
      verifyNever(() => locator.captureCoordinates());
      verifyNever(() => locator.captureCoordinatesIfGranted());
      verifyNever(() => tracking.sendPosition(any(), any(), any()));
      verifySkipped('no_permission');
    },
  );

  blocTest<PositionReporterCubit, PositionReporterState>(
    'skips with no_position when no fix is available',
    build: build,
    setUp: () {
      trips([_trip('a', active: true)]);
      when(
        () => locator.captureCoordinatesIfGranted(),
      ).thenAnswer((_) async => null);
    },
    act: (c) => c.onResume(),
    verify: (_) => verifySkipped('no_position'),
  );

  blocTest<PositionReporterCubit, PositionReporterState>(
    'swallowsNetworkErrors',
    build: build,
    setUp: () {
      trips([_trip('a', active: true), _trip('b', active: true)]);
      when(
        () => tracking.sendPosition('a', any(), any()),
      ).thenThrow(DioException(requestOptions: RequestOptions(path: '/x')));
    },
    act: (c) => c.onResume(),
    verify: (_) {
      verify(() => tracking.sendPosition('b', any(), any())).called(1);
    },
  );

  test('swallows a failure of the trips call', () async {
    when(
      () => announcements.getMyAnnouncements(),
    ).thenThrow(DioException(requestOptions: RequestOptions(path: '/x')));
    await build().onResume();
    verifyNever(() => tracking.sendPosition(any(), any(), any()));
  });

  test('throttlesToOncePer15Minutes', () async {
    trips([_trip('a', active: true)]);
    final cubit = build();
    await cubit.onResume();
    clock = clock.add(const Duration(minutes: 14));
    await cubit.onResume();
    verify(() => tracking.sendPosition('a', any(), any())).called(1);
    verifySkipped('throttled');
    clock = clock.add(const Duration(minutes: 2));
    await cubit.onResume();
    verify(() => tracking.sendPosition('a', any(), any())).called(1);
  });

  test('doesNothingWithoutRealSession', () async {
    session = false;
    trips([_trip('a', active: true)]);
    await build().onResume();
    verifyNever(() => announcements.getMyAnnouncements());
    verifyNever(() => tracking.sendPosition(any(), any(), any()));
    verifySkipped('no_session');
  });

  test('capsAtThreeTrips', () async {
    trips([
      for (final i in ['a', 'b', 'c', 'd', 'e']) _trip(i, active: true),
    ]);
    await build().onResume();
    verify(() => tracking.sendPosition(any(), any(), any())).called(3);
    verifyNever(() => tracking.sendPosition('d', any(), any()));
  });
}
