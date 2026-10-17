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
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockFavoriteTripsCubit extends MockCubit<FavoriteTripsState>
    implements FavoriteTripsCubit {}

class _MockFavoriteRequestsCubit extends MockCubit<FavoriteRequestsState>
    implements FavoriteRequestsCubit {}

class _MockFavoriteIdsCubit extends MockCubit<FavoriteIdsState>
    implements FavoriteIdsCubit {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _FakeAnalyticsService extends Fake implements AnalyticsService {
  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?>? properties,
  }) async {}
}

AnnouncementModel _trip({required String travelerId}) {
  final now = DateTime.now();
  return AnnouncementModel(
    id: 'trip-1',
    travelerId: travelerId,
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(now.year, now.month + 1, 15),
    availableKg: 12,
    totalKg: 20,
    pricePerKg: 8,
    status: 'ACTIVE',
    createdAt: now,
    updatedAt: now,
  );
}

Widget _app(AnnouncementModel trip) {
  final idsCubit = _MockFavoriteIdsCubit();
  when(() => idsCubit.state).thenReturn(FavoriteIdsState({trip.id}, const {}));
  when(() => idsCubit.load()).thenAnswer((_) async {});
  when(() => idsCubit.isTripFav(any())).thenReturn(true);

  final tripsCubit = _MockFavoriteTripsCubit();
  when(() => tripsCubit.state).thenReturn(FavoriteTripsLoaded([trip]));
  when(() => tripsCubit.load()).thenAnswer((_) async {});

  final requestsCubit = _MockFavoriteRequestsCubit();
  when(() => requestsCubit.state).thenReturn(FavoriteRequestsLoading());

  final authBloc = _MockAuthBloc();
  when(() => authBloc.state).thenReturn(
    const AuthAuthenticated(
      UserModel(
        id: 'me',
        roles: ['SENDER'],
        kycStatus: 'VERIFIED',
        status: 'ACTIVE',
      ),
    ),
  );

  final bidBloc = _MockBidBloc();
  when(() => bidBloc.state).thenReturn(BidInitial());

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const FavoritesScreen()),
      GoRoute(
        path: '/announcements/:id/trip',
        builder: (_, state) => Scaffold(
          body: Text('Écran propriétaire ${state.pathParameters['id']}'),
        ),
      ),
    ],
  );

  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<BidBloc>.value(value: bidBloc),
      BlocProvider<FavoriteTripsCubit>.value(value: tripsCubit),
      BlocProvider<FavoriteRequestsCubit>.value(value: requestsCubit),
      BlocProvider<FavoriteIdsCubit>.value(value: idsCubit),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: AppL10n.fr,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  // Timers flutter_animate des cartes : plusieurs pas plutôt qu'un settle.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  setUpAll(() {
    initializeDateFormatting('fr');
    if (!getIt.isRegistered<AnalyticsService>()) {
      getIt.registerSingleton<AnalyticsService>(_FakeAnalyticsService());
    }
  });

  tearDownAll(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  // FLUTTER-R9 : son propre trajet mis en favori ouvrait la feuille
  // expéditeur, avec « Faire une demande » sur son propre trajet.
  testWidgets('son propre trajet → écran propriétaire, pas la feuille', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_trip(travelerId: 'me')));
    await _settle(tester);

    await tester.tap(find.byType(TripCard));
    await _settle(tester);

    expect(find.text('Écran propriétaire trip-1'), findsOneWidget);
    expect(find.text('Détail du trajet'), findsNothing);
  });

  testWidgets('trajet d\'un autre voyageur → feuille trajet expéditeur', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_trip(travelerId: 'someone-else')));
    await _settle(tester);

    await tester.tap(find.byType(TripCard));
    await _settle(tester);

    expect(find.text('Détail du trajet'), findsOneWidget);
    expect(find.text('Écran propriétaire trip-1'), findsNothing);
  });
}
