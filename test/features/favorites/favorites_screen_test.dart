import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
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

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

UserModel _makeUser({required bool isTraveler}) => UserModel(
  id: 'user-1',
  roles: isTraveler ? ['TRAVELER', 'SENDER'] : ['SENDER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

// ---------------------------------------------------------------------------
// Helper to build the widget
// ---------------------------------------------------------------------------

Widget _buildScreen({
  required bool isTraveler,
  required FavoriteTripsState tripsState,
  required FavoriteRequestsState requestsState,
}) {
  final favoriteIdsCubit = _MockFavoriteIdsCubit();
  when(() => favoriteIdsCubit.state).thenReturn(const FavoriteIdsState({}, {}));
  when(() => favoriteIdsCubit.load()).thenAnswer((_) async {});

  final tripsCubit = _MockFavoriteTripsCubit();
  when(() => tripsCubit.state).thenReturn(tripsState);
  when(() => tripsCubit.load()).thenAnswer((_) async {});
  when(() => tripsCubit.refresh()).thenAnswer((_) async {});

  final requestsCubit = _MockFavoriteRequestsCubit();
  when(() => requestsCubit.state).thenReturn(requestsState);
  when(() => requestsCubit.load()).thenAnswer((_) async {});
  when(() => requestsCubit.refresh()).thenAnswer((_) async {});

  final authBloc = _MockAuthBloc();
  when(
    () => authBloc.state,
  ).thenReturn(AuthAuthenticated(_makeUser(isTraveler: isTraveler)));

  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<FavoriteTripsCubit>.value(value: tripsCubit),
        BlocProvider<FavoriteRequestsCubit>.value(value: requestsCubit),
        BlocProvider<FavoriteIdsCubit>.value(value: favoriteIdsCubit),
      ],
      child: const FavoritesScreen(),
    ),
  );
}

class _FakeAnalyticsService extends Fake implements AnalyticsService {
  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?>? properties,
  }) async {}
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
  // Traveler capability → 2 tabs
  // ---------------------------------------------------------------------------
  group('FavoritesScreen — capacité voyageur', () {
    testWidgets('affiche 2 onglets "Trajets" et "Demandes"', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          isTraveler: true,
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
          isTraveler: true,
          tripsState: FavoriteTripsLoading(),
          requestsState: FavoriteRequestsLoading(),
        ),
      );
      await tester.pump();

      final controller = DefaultTabController.maybeOf(
        tester.element(find.byType(TabBar)),
      );
      expect(controller, isNotNull);
      expect(controller!.length, 2);
    });

    // Key regression test: traveler capability gates the tab, not active role.
    // A user with TRAVELER role must see both tabs regardless of ActiveRoleCubit.
    testWidgets('voyageur avec capacité isTraveler=true voit les 2 onglets '
        'indépendamment du rôle actif (ActiveRoleCubit ignoré)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(
          isTraveler: true,
          tripsState: FavoriteTripsLoading(),
          requestsState: FavoriteRequestsLoading(),
        ),
      );
      await tester.pump();

      // Should have both tabs purely from isTraveler capability
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Trajets'), findsOneWidget);
      expect(find.text('Demandes'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Sender-only capability → no tab bar, single list
  // ---------------------------------------------------------------------------
  group('FavoritesScreen — capacité expéditeur uniquement', () {
    testWidgets('n\'affiche pas de TabBar', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          isTraveler: false,
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
          isTraveler: false,
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
    testWidgets('affiche l\'état vide quand FavoriteTripsEmpty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(
          isTraveler: false,
          tripsState: FavoriteTripsEmpty(),
          requestsState: FavoriteRequestsLoading(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Aucun favori pour l\'instant'), findsOneWidget);
    });

    testWidgets('affiche l\'état vide pour les demandes (voyageur)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(
          isTraveler: true,
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
          isTraveler: false,
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
          isTraveler: false,
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
          isTraveler: false,
          tripsState: FavoriteTripsLoading(),
          requestsState: FavoriteRequestsLoading(),
        ),
      );
      await tester.pump();

      expect(find.text('Mes favoris'), findsOneWidget);
    });
  });
}
