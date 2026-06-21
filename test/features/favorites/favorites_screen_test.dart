import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/bloc/favorite_requests_cubit.dart';
import 'package:dony/features/favorites/bloc/favorite_trips_cubit.dart';
import 'package:dony/features/favorites/presentation/favorites_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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

// ---------------------------------------------------------------------------
// Helper to build the widget
// ---------------------------------------------------------------------------

Widget _buildScreen({
  required ActiveRole role,
  required FavoriteTripsState tripsState,
  required FavoriteRequestsState requestsState,
}) {
  final favoriteIdsCubit = _MockFavoriteIdsCubit();
  when(() => favoriteIdsCubit.state)
      .thenReturn(const FavoriteIdsState({}, {}));
  when(() => favoriteIdsCubit.load()).thenAnswer((_) async {});

  final tripsCubit = _MockFavoriteTripsCubit();
  when(() => tripsCubit.state).thenReturn(tripsState);
  when(() => tripsCubit.load()).thenAnswer((_) async {});
  when(() => tripsCubit.refresh()).thenAnswer((_) async {});

  final requestsCubit = _MockFavoriteRequestsCubit();
  when(() => requestsCubit.state).thenReturn(requestsState);
  when(() => requestsCubit.load()).thenAnswer((_) async {});
  when(() => requestsCubit.refresh()).thenAnswer((_) async {});

  // ActiveRoleCubit backed by a real hive-less implementation would require
  // hive init. Instead use MockCubit.
  final roleCubit = _MockActiveRoleCubit();
  when(() => roleCubit.state).thenReturn(role);

  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<ActiveRoleCubit>.value(value: roleCubit),
        BlocProvider<FavoriteTripsCubit>.value(value: tripsCubit),
        BlocProvider<FavoriteRequestsCubit>.value(value: requestsCubit),
        BlocProvider<FavoriteIdsCubit>.value(value: favoriteIdsCubit),
      ],
      child: const FavoritesScreen(),
    ),
  );
}

class _MockActiveRoleCubit extends MockCubit<ActiveRole>
    implements ActiveRoleCubit {}

class _FakeAnalyticsService extends Fake implements AnalyticsService {
  @override
  Future<void> logEvent(String name, {Map<String, Object?>? properties}) async {}
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
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
  // Traveler role → 2 tabs
  // ---------------------------------------------------------------------------
  group('FavoritesScreen — rôle voyageur', () {
    testWidgets('affiche 2 onglets "Trajets" et "Demandes"', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          role: ActiveRole.traveler,
          tripsState: FavoriteTripsLoading(),
          requestsState: FavoriteRequestsLoading(),
        ),
      );
      await tester.pump();

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Trajets'), findsOneWidget);
      expect(find.text('Demandes'), findsOneWidget);
    });

    testWidgets('affiche DefaultTabController avec length 2', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          role: ActiveRole.traveler,
          tripsState: FavoriteTripsLoading(),
          requestsState: FavoriteRequestsLoading(),
        ),
      );
      await tester.pump();

      final controller =
          DefaultTabController.maybeOf(tester.element(find.byType(TabBar)));
      expect(controller, isNotNull);
      expect(controller!.length, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // Sender role → no tab bar, single list
  // ---------------------------------------------------------------------------
  group('FavoritesScreen — rôle expéditeur', () {
    testWidgets('n\'affiche pas de TabBar', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          role: ActiveRole.sender,
          tripsState: FavoriteTripsLoading(),
          requestsState: FavoriteRequestsLoading(),
        ),
      );
      await tester.pump();

      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('n\'affiche pas l\'onglet "Demandes"', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          role: ActiveRole.sender,
          tripsState: FavoriteTripsLoading(),
          requestsState: FavoriteRequestsLoading(),
        ),
      );
      await tester.pump();

      expect(find.text('Demandes'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------
  group('FavoritesScreen — état vide', () {
    testWidgets('affiche l\'état vide quand FavoriteTripsEmpty', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          role: ActiveRole.sender,
          tripsState: FavoriteTripsEmpty(),
          requestsState: FavoriteRequestsLoading(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Aucun favori pour l\'instant'), findsOneWidget);
    });

    testWidgets('affiche l\'état vide pour les demandes (voyageur)',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          role: ActiveRole.traveler,
          tripsState: FavoriteTripsEmpty(),
          requestsState: FavoriteRequestsEmpty(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // First tab (Trajets) is visible → empty state
      expect(find.text('Aucun favori pour l\'instant'), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // Error state
  // ---------------------------------------------------------------------------
  group('FavoritesScreen — état erreur', () {
    testWidgets('affiche le bouton Réessayer en cas d\'erreur', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          role: ActiveRole.sender,
          tripsState: FavoriteTripsError('network error'),
          requestsState: FavoriteRequestsLoading(),
        ),
      );
      await tester.pump();

      expect(find.text('Réessayer'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Loading state
  // ---------------------------------------------------------------------------
  group('FavoritesScreen — état chargement', () {
    testWidgets('affiche un spinner CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          role: ActiveRole.sender,
          tripsState: FavoriteTripsLoading(),
          requestsState: FavoriteRequestsLoading(),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Title
  // ---------------------------------------------------------------------------
  group('FavoritesScreen — titre', () {
    testWidgets('affiche "Mes favoris" dans l\'AppBar', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          role: ActiveRole.sender,
          tripsState: FavoriteTripsLoading(),
          requestsState: FavoriteRequestsLoading(),
        ),
      );
      await tester.pump();

      expect(find.text('Mes favoris'), findsOneWidget);
    });
  });
}
