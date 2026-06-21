import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/bloc/favorite_requests_cubit.dart';
import 'package:dony/features/favorites/bloc/favorite_trips_cubit.dart';
import 'package:dony/features/favorites/presentation/favorites_screen.dart';
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockFavoriteTripsCubit extends MockCubit<FavoriteTripsState>
    implements FavoriteTripsCubit {}

class _MockFavoriteRequestsCubit extends MockCubit<FavoriteRequestsState>
    implements FavoriteRequestsCubit {}

class _MockFavoriteIdsCubit extends MockCubit<FavoriteIdsState>
    implements FavoriteIdsCubit {}

class _MockActiveRoleCubit extends MockCubit<ActiveRole>
    implements ActiveRoleCubit {}

class _FakeAnalyticsService extends Fake implements AnalyticsService {
  @override
  Future<void> logEvent(String name, {Map<String, Object?>? properties}) async {}
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildScreen({
  required ActiveRole role,
  required FavoriteTripsState tripsState,
  required FavoriteRequestsState requestsState,
  _MockFavoriteTripsCubit? tripsCubitOverride,
  _MockFavoriteRequestsCubit? requestsCubitOverride,
}) {
  final idsCubit = _MockFavoriteIdsCubit();
  when(() => idsCubit.state).thenReturn(const FavoriteIdsState({}, {}));
  when(() => idsCubit.load()).thenAnswer((_) async {});
  when(() => idsCubit.isTripFav(any())).thenReturn(false);
  when(() => idsCubit.isRequestFav(any())).thenReturn(false);
  when(() => idsCubit.count).thenReturn(0);

  final tripsCubit = tripsCubitOverride ?? _MockFavoriteTripsCubit();
  when(() => tripsCubit.state).thenReturn(tripsState);
  when(() => tripsCubit.load()).thenAnswer((_) async {});
  when(() => tripsCubit.refresh()).thenAnswer((_) async {});

  final requestsCubit =
      requestsCubitOverride ?? _MockFavoriteRequestsCubit();
  when(() => requestsCubit.state).thenReturn(requestsState);
  when(() => requestsCubit.load()).thenAnswer((_) async {});
  when(() => requestsCubit.refresh()).thenAnswer((_) async {});

  final roleCubit = _MockActiveRoleCubit();
  when(() => roleCubit.state).thenReturn(role);

  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<ActiveRoleCubit>.value(value: roleCubit),
        BlocProvider<FavoriteTripsCubit>.value(value: tripsCubit),
        BlocProvider<FavoriteRequestsCubit>.value(value: requestsCubit),
        BlocProvider<FavoriteIdsCubit>.value(value: idsCubit),
      ],
      child: const FavoritesScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    // FavoritesScreen calls getIt<AnalyticsService>() in initState — register
    // a no-op fake so tests don't crash with GetIt not-registered errors.
    if (!getIt.isRegistered<AnalyticsService>()) {
      getIt.registerSingleton<AnalyticsService>(_FakeAnalyticsService());
    }
  });

  tearDownAll(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  // ---------------------------------------------------------------------------
  // Retry button — trips tab
  // ---------------------------------------------------------------------------
  group('FavoritesScreen — retry déclenche load()', () {
    testWidgets('tap Réessayer appelle trips.load()', (tester) async {
      final tripsCubit = _MockFavoriteTripsCubit();
      when(() => tripsCubit.state).thenReturn(FavoriteTripsError('err'));
      when(() => tripsCubit.load()).thenAnswer((_) async {});

      await tester.pumpWidget(_buildScreen(
        role: ActiveRole.sender,
        tripsState: FavoriteTripsError('err'),
        requestsState: FavoriteRequestsLoading(),
        tripsCubitOverride: tripsCubit,
      ));
      await tester.pump();

      expect(find.text('Réessayer'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      verify(() => tripsCubit.load()).called(greaterThanOrEqualTo(1));
    });

    testWidgets('tap Réessayer (requests tab) appelle requests.load()',
        (tester) async {
      final requestsCubit = _MockFavoriteRequestsCubit();
      when(() => requestsCubit.state)
          .thenReturn(FavoriteRequestsError('err'));
      when(() => requestsCubit.load()).thenAnswer((_) async {});
      when(() => requestsCubit.refresh()).thenAnswer((_) async {});

      await tester.pumpWidget(_buildScreen(
        role: ActiveRole.traveler,
        tripsState: FavoriteTripsLoading(),
        requestsState: FavoriteRequestsError('err'),
        requestsCubitOverride: requestsCubit,
      ));
      await tester.pump();

      // Navigate to the Demandes tab (index 1) and wait for animation
      await tester.tap(find.text('Demandes'));
      await tester.pumpAndSettle();

      // The Réessayer button must be visible in the _RequestsTab error state
      expect(find.text('Réessayer'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      verify(() => requestsCubit.load()).called(greaterThanOrEqualTo(1));
    });
  });

  // ---------------------------------------------------------------------------
  // Error state — trips tab text content
  // ---------------------------------------------------------------------------
  group('FavoritesScreen — error state text', () {
    testWidgets('affiche "Une erreur est survenue"', (tester) async {
      await tester.pumpWidget(_buildScreen(
        role: ActiveRole.sender,
        tripsState: FavoriteTripsError('something'),
        requestsState: FavoriteRequestsLoading(),
      ));
      await tester.pump();

      expect(find.text('Une erreur est survenue'), findsOneWidget);
      expect(
        find.text('Impossible de charger vos favoris.'),
        findsOneWidget,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // FavoriteHeartButton animation — _handleToggle triggers _controller.forward
  // ---------------------------------------------------------------------------
  group('FavoriteHeartButton — animation plays on tap', () {
    testWidgets('animation controller runs through on tap (no exception)',
        (tester) async {
      var toggleCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Center(
                child: FavoriteHeartButton(
                  isFavorite: toggleCount.isEven,
                  onToggle: () => setState(() => toggleCount++),
                ),
              );
            },
          ),
        ),
      ));

      // Initial state: unfavorited
      expect(find.byType(FavoriteHeartButton), findsOneWidget);

      // Tap → animation forward (0→1.25→1) — should not throw
      await tester.tap(find.byType(FavoriteHeartButton));
      // Pump through entire animation (200 ms)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(toggleCount, 1);

      // Tap again → another animation cycle
      await tester.tap(find.byType(FavoriteHeartButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(toggleCount, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // FavoriteTripsLoaded — ListView visible
  // ---------------------------------------------------------------------------
  group('FavoritesScreen — état chargé (trajets)', () {
    setUpAll(() => initializeDateFormatting('fr'));

    AnnouncementModel makeTrip() => AnnouncementModel.fromJson({
          'id': 'trip-1',
          'travelerId': 'tv1',
          'departureCity': 'Paris',
          'arrivalCity': 'Dakar',
          'departureDate':
              DateTime.now().add(const Duration(days: 5)).toIso8601String(),
          'totalKg': 20.0,
          'availableKg': 15.0,
          'pricePerKg': 8.0,
          'pricingMode': 'KG',
          'status': 'ACTIVE',
          'pendingBidCount': 0,
          'confirmedParcelCount': 0,
          'createdAt': '2024-01-01T00:00:00Z',
          'updatedAt': '2024-01-01T00:00:00Z',
        });

    testWidgets('affiche RefreshIndicator et ListView quand FavoriteTripsLoaded',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          role: ActiveRole.sender,
          tripsState: FavoriteTripsLoaded([makeTrip()]),
          requestsState: FavoriteRequestsLoading(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('état vide pour les trajets : message spécifique visible',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          role: ActiveRole.sender,
          tripsState: FavoriteTripsEmpty(),
          requestsState: FavoriteRequestsLoading(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text("Aucun trajet favori pour l'instant"),
        findsOneWidget,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // FavoriteRequestsLoaded — ListView visible (traveler tab)
  // ---------------------------------------------------------------------------
  group('FavoritesScreen — état chargé (demandes)', () {
    setUpAll(() => initializeDateFormatting('fr'));

    PackageRequestSearchItem makeRequest() => PackageRequestSearchItem(
          id: 'req-1',
          departureCity: 'Lyon',
          arrivalCity: 'Abidjan',
          desiredDate: DateTime(2025, 7),
          dateToleranceDays: 3,
          weightKg: 4.0,
          parcelSize: ParcelSize.medium,
          sender: const SenderPublicProfile(
            id: 's1',
            displayName: 'Moussa',
            averageRating: 4.5,
            totalRatings: 8,
            kycVerified: true,
          ),
        );

    testWidgets(
        'FavoriteRequestsLoaded : affiche ListView dans l\'onglet Demandes',
        (tester) async {
      final requestsCubit = _MockFavoriteRequestsCubit();
      when(() => requestsCubit.state)
          .thenReturn(FavoriteRequestsLoaded([makeRequest()]));
      when(() => requestsCubit.load()).thenAnswer((_) async {});
      when(() => requestsCubit.refresh()).thenAnswer((_) async {});

      await tester.pumpWidget(
        _buildScreen(
          role: ActiveRole.traveler,
          tripsState: FavoriteTripsLoading(),
          requestsState: FavoriteRequestsLoaded([makeRequest()]),
          requestsCubitOverride: requestsCubit,
        ),
      );

      // Navigate to the Demandes tab so it actually renders
      await tester.tap(find.text('Demandes'));
      await tester.pumpAndSettle();

      // The tab must render the loaded list
      expect(find.byType(RefreshIndicator), findsAtLeastNWidgets(1));
      expect(find.byType(PackageRequestListCard), findsOneWidget);
    });

    testWidgets(
        'FavoriteRequestsEmpty : affiche message vide dans l\'onglet Demandes',
        (tester) async {
      final requestsCubit = _MockFavoriteRequestsCubit();
      when(() => requestsCubit.state).thenReturn(FavoriteRequestsEmpty());
      when(() => requestsCubit.load()).thenAnswer((_) async {});
      when(() => requestsCubit.refresh()).thenAnswer((_) async {});

      await tester.pumpWidget(
        _buildScreen(
          role: ActiveRole.traveler,
          tripsState: FavoriteTripsLoading(),
          requestsState: FavoriteRequestsEmpty(),
          requestsCubitOverride: requestsCubit,
        ),
      );

      // Navigate to the Demandes tab so it actually renders
      await tester.tap(find.text('Demandes'));
      await tester.pumpAndSettle();

      expect(
        find.text("Aucune demande favorite pour l'instant"),
        findsOneWidget,
      );
    });
  });
}
