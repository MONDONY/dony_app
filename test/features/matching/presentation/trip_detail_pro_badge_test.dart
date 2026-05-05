import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/services/saved_trips_service.dart';
import 'package:dony/features/matching/presentation/screens/traveler_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockSavedTripsService extends Mock implements SavedTripsService {}

AnnouncementModel _makeAnnouncement({required bool isProAccount}) {
  return AnnouncementModel(
    id: 'ann-001',
    travelerId: 'traveler-001',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(2025, 8, 15),
    availableKg: 10,
    totalKg: 23,
    pricePerKg: 8,
    status: 'OPEN',
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
    traveler: TravelerProfile(
      id: 'traveler-001',
      displayName: 'Mamadou Diallo',
      isProAccount: isProAccount,
    ),
  );
}

/// Duration long enough to let all flutter_animate delays complete.
const _kSettle = Duration(milliseconds: 600);

Widget _wrap(AnnouncementModel announcement) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => TravelerProfileScreen(
            announcement: announcement,
            consultOnly: true,
          ),
        ),
      ],
    ),
  );
}

void main() {
  late MockSavedTripsService mockSavedTripsService;

  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  setUp(() {
    mockSavedTripsService = MockSavedTripsService();
    when(() => mockSavedTripsService.isSaved(any())).thenReturn(false);

    if (getIt.isRegistered<SavedTripsService>()) {
      getIt.unregister<SavedTripsService>();
    }
    getIt.registerLazySingleton<SavedTripsService>(
      () => mockSavedTripsService,
    );
  });

  tearDown(() {
    if (getIt.isRegistered<SavedTripsService>()) {
      getIt.unregister<SavedTripsService>();
    }
  });

  group('TravelerProfileScreen — PRO badge', () {
    testWidgets('shows PRO badge when isProAccount is true', (tester) async {
      final announcement = _makeAnnouncement(isProAccount: true);

      await tester.pumpWidget(_wrap(announcement));
      await tester.pump(_kSettle);

      expect(find.text('PRO'), findsOneWidget);
    });

    testWidgets('does NOT show PRO badge when isProAccount is false',
        (tester) async {
      final announcement = _makeAnnouncement(isProAccount: false);

      await tester.pumpWidget(_wrap(announcement));
      await tester.pump(_kSettle);

      expect(find.text('PRO'), findsNothing);
    });

    testWidgets('shows traveler name alongside PRO badge', (tester) async {
      final announcement = _makeAnnouncement(isProAccount: true);

      await tester.pumpWidget(_wrap(announcement));
      await tester.pump(_kSettle);

      expect(find.text('Mamadou Diallo'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
    });
  });
}
