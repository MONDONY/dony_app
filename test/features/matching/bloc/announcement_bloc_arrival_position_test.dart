import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements AnnouncementRepository {}

class _MockLocator extends Mock implements ScanLocator {}

AnnouncementModel _ann() => AnnouncementModel(
  id: 'a1',
  travelerId: 't1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 7),
  availableKg: 10,
  totalKg: 20,
  pricePerKg: 8,
  status: 'ARRIVED',
  bidsCount: 0,
  createdAt: DateTime(2026, 6),
  updatedAt: DateTime(2026, 6),
);

void main() {
  late _MockRepo repo;
  late _MockLocator locator;

  setUp(() {
    repo = _MockRepo();
    locator = _MockLocator();
  });

  Future<AnnouncementBloc> build() async {
    final analytics = makeDisabledAnalytics(MockAnalyticsBackend());
    await analytics.onConfigured();
    return AnnouncementBloc(repo, analytics, locator: locator);
  }

  Future<void> run(AnnouncementBloc bloc) async {
    bloc.add(AnnouncementTripMarkArrivedRequested(announcementId: 'a1'));
    await expectLater(
      bloc.stream,
      emitsThrough(isA<AnnouncementTripArrived>()),
    );
    await bloc.close();
  }

  test('markArrivedSendsPositionWhenGranted', () async {
    when(
      () => locator.captureCoordinatesIfGranted(),
    ).thenAnswer((_) async => const ScanPosition(lat: 14.7, lon: -17.4));
    when(
      () => repo.markTripArrived(
        announcementId: 'a1',
        arrivalInstructions: any(named: 'arrivalInstructions'),
        position: any(named: 'position'),
      ),
    ).thenAnswer((_) async => _ann());
    await run(await build());
    verify(
      () => repo.markTripArrived(
        announcementId: 'a1',
        position: (lat: 14.7, lon: -17.4),
      ),
    ).called(1);
  });

  test('markArrivedWithoutPositionBodyUnchanged', () async {
    when(
      () => locator.captureCoordinatesIfGranted(),
    ).thenAnswer((_) async => null);
    when(
      () => repo.markTripArrived(
        announcementId: 'a1',
        arrivalInstructions: any(named: 'arrivalInstructions'),
        position: any(named: 'position'),
      ),
    ).thenAnswer((_) async => _ann());
    await run(await build());
    verify(() => repo.markTripArrived(announcementId: 'a1')).called(1);
  });

  test('markArrivedNotBlockedWhenPositionCaptureFails', () async {
    when(() => locator.captureCoordinatesIfGranted()).thenThrow(Exception('x'));
    when(
      () => repo.markTripArrived(
        announcementId: 'a1',
        arrivalInstructions: any(named: 'arrivalInstructions'),
        position: any(named: 'position'),
      ),
    ).thenAnswer((_) async => _ann());
    await run(await build());
    verify(() => repo.markTripArrived(announcementId: 'a1')).called(1);
  });
}
