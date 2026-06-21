import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/traveler_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockFavoriteRepository extends Mock implements FavoriteRepository {}

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

Widget _wrap(
  AnnouncementModel announcement,
  FavoriteIdsCubit cubit, {
  bool consultOnly = true,
}) {
  return BlocProvider<FavoriteIdsCubit>.value(
    value: cubit,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => TravelerProfileScreen(
              announcement: announcement,
              consultOnly: consultOnly,
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  group('TravelerProfileScreen — PRO badge', () {
    late FavoriteIdsCubit cubit;
    late MockFavoriteRepository mockRepo;

    setUp(() {
      mockRepo = MockFavoriteRepository();
      cubit = FavoriteIdsCubit(mockRepo);
    });

    tearDown(() {
      cubit.close();
    });

    testWidgets('shows PRO badge when isProAccount is true', (tester) async {
      final announcement = _makeAnnouncement(isProAccount: true);

      await tester.pumpWidget(_wrap(announcement, cubit));
      await tester.pump(_kSettle);

      expect(find.text('PRO'), findsOneWidget);
    });

    testWidgets('does NOT show PRO badge when isProAccount is false',
        (tester) async {
      final announcement = _makeAnnouncement(isProAccount: false);

      await tester.pumpWidget(_wrap(announcement, cubit));
      await tester.pump(_kSettle);

      expect(find.text('PRO'), findsNothing);
    });

    testWidgets('shows traveler name alongside PRO badge', (tester) async {
      final announcement = _makeAnnouncement(isProAccount: true);

      await tester.pumpWidget(_wrap(announcement, cubit));
      await tester.pump(_kSettle);

      expect(find.text('Mamadou Diallo'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
    });
  });

  group('TravelerProfileScreen — heart toggle snackbar (I1)', () {
    late FavoriteIdsCubit cubit;
    late MockFavoriteRepository mockRepo;

    setUp(() {
      mockRepo = MockFavoriteRepository();
      cubit = FavoriteIdsCubit(mockRepo);
    });

    tearDown(() {
      cubit.close();
    });

    testWidgets('shows success snackbar when trip is added to favorites',
        (tester) async {
      final announcement = _makeAnnouncement(isProAccount: false);
      when(() => mockRepo.add('trip', 'ann-001')).thenAnswer((_) async {});

      await tester.pumpWidget(
        _wrap(announcement, cubit, consultOnly: false),
      );
      await tester.pump(_kSettle);

      // Tap the FavoriteHeartButton
      await tester.tap(find.byType(FavoriteHeartButton));
      // Pump to process the async toggle + snackbar render
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Trajet ajouté aux favoris'), findsOneWidget);
    });

    testWidgets('shows info snackbar when trip is removed from favorites',
        (tester) async {
      final announcement = _makeAnnouncement(isProAccount: false);
      // Seed as already favorite
      cubit.emitSeed(trips: {'ann-001'}, requests: {});
      when(() => mockRepo.remove('trip', 'ann-001')).thenAnswer((_) async {});

      await tester.pumpWidget(
        _wrap(announcement, cubit, consultOnly: false),
      );
      await tester.pump(_kSettle);

      // Tap to remove
      await tester.tap(find.byType(FavoriteHeartButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Trajet retiré des favoris'), findsOneWidget);
    });

    testWidgets('shows error snackbar when toggle throws', (tester) async {
      final announcement = _makeAnnouncement(isProAccount: false);
      when(() => mockRepo.add('trip', 'ann-001'))
          .thenThrow(Exception('network error'));

      await tester.pumpWidget(
        _wrap(announcement, cubit, consultOnly: false),
      );
      await tester.pump(_kSettle);

      await tester.tap(find.byType(FavoriteHeartButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Impossible de modifier les favoris'), findsOneWidget);
    });
  });
}
