import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncementRepo extends Mock implements AnnouncementRepository {}

class _MockBidRepo extends Mock implements BidRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

AnnouncementModel _trip(String id, String status) => AnnouncementModel(
      id: id,
      travelerId: 'traveler-1',
      status: status,
      departureDate: DateTime(2026, 6, 10),
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      availableKg: 10,
      totalKg: 20,
      pricePerKg: 5,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  late _MockAnnouncementRepo annRepo;
  late _MockBidRepo bidRepo;
  late _MockAnalytics analytics;

  setUp(() {
    annRepo = _MockAnnouncementRepo();
    bidRepo = _MockBidRepo();
    analytics = _MockAnalytics();
  });

  blocTest<ScanHubCubit, ScanHubState>(
    'aucun trajet → ScanHubEmpty',
    build: () {
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async => (announcements: <AnnouncementModel>[], totalElements: 0),
      );
      return ScanHubCubit(annRepo, bidRepo, analytics);
    },
    act: (c) => c.load(),
    expect: () => [isA<ScanHubLoading>(), isA<ScanHubEmpty>()],
  );

  blocTest<ScanHubCubit, ScanHubState>(
    'trajet IN_PROGRESS → ScanHubLoaded',
    build: () {
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async =>
            (announcements: [_trip('a', 'IN_PROGRESS')], totalElements: 1),
      );
      when(() => bidRepo.getBidsForAnnouncement('a'))
          .thenAnswer((_) async => []);
      return ScanHubCubit(annRepo, bidRepo, analytics);
    },
    act: (c) => c.load(),
    expect: () => [isA<ScanHubLoading>(), isA<ScanHubLoaded>()],
  );

  blocTest<ScanHubCubit, ScanHubState>(
    'erreur réseau → ScanHubError',
    build: () {
      when(() => annRepo.getMyAnnouncements())
          .thenThrow(Exception('Network error'));
      return ScanHubCubit(annRepo, bidRepo, analytics);
    },
    act: (c) => c.load(),
    expect: () => [isA<ScanHubLoading>(), isA<ScanHubError>()],
  );

  blocTest<ScanHubCubit, ScanHubState>(
    'trajet ACTIVE sans bids → ScanHubLoaded avec compteurs à zéro',
    build: () {
      when(() => annRepo.getMyAnnouncements()).thenAnswer(
        (_) async =>
            (announcements: [_trip('b', 'ACTIVE')], totalElements: 1),
      );
      when(() => bidRepo.getBidsForAnnouncement('b'))
          .thenAnswer((_) async => []);
      return ScanHubCubit(annRepo, bidRepo, analytics);
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
}
