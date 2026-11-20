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
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:dony/features/likes/bloc/trip_likes_cubit.dart';
import 'package:dony/features/likes/data/models/trip_like_status.dart';
import 'package:dony/features/likes/data/repositories/trip_like_repository.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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

class _MockLikeRepo extends Mock implements TripLikeRepository {}

class _FakeAnalyticsService extends Fake implements AnalyticsService {
  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?>? properties,
  }) async {}
}

AnnouncementModel _trip(
  String id, {
  required String travelerId,
  int likes = 0,
}) {
  final now = DateTime.now();
  return AnnouncementModel(
    id: id,
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
    likeCount: likes,
    likedByMe: likes > 0,
  );
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

  testWidgets(
    'favoris : la liste reçue alimente les j\'aime, son trajet en lecture '
    'seule avec son signet',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final other = _trip('trip-other', travelerId: 'tv1', likes: 7);
      final own = _trip('trip-own', travelerId: 'me', likes: 3);
      final loaded = FavoriteTripsLoaded([other, own]);

      final tripsCubit = _MockFavoriteTripsCubit();
      when(() => tripsCubit.load()).thenAnswer((_) async {});
      when(() => tripsCubit.refresh()).thenAnswer((_) async {});
      whenListen(
        tripsCubit,
        Stream<FavoriteTripsState>.value(loaded),
        initialState: FavoriteTripsLoading(),
      );

      final requestsCubit = _MockFavoriteRequestsCubit();
      when(() => requestsCubit.state).thenReturn(FavoriteRequestsLoading());

      final idsCubit = _MockFavoriteIdsCubit();
      when(
        () => idsCubit.state,
      ).thenReturn(const FavoriteIdsState({'trip-other', 'trip-own'}, {}));
      when(() => idsCubit.load()).thenAnswer((_) async {});
      when(() => idsCubit.isTripFav(any())).thenReturn(true);

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

      final likes = TripLikesCubit(_MockLikeRepo(), _FakeAnalyticsService());
      addTearDown(likes.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<FavoriteTripsCubit>.value(value: tripsCubit),
            BlocProvider<FavoriteRequestsCubit>.value(value: requestsCubit),
            BlocProvider<FavoriteIdsCubit>.value(value: idsCubit),
            BlocProvider<TripLikesCubit>.value(value: likes),
          ],
          child: const MaterialApp(
            locale: AppL10n.fr,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FavoritesScreen(),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(
        likes.state.byTrip['trip-other'],
        const TripLikeStatus(likeCount: 7, likedByMe: true),
      );
      expect(
        likes.state.byTrip['trip-own'],
        const TripLikeStatus(likeCount: 3, likedByMe: true),
      );
      // Trajet d'un autre : ♡ actif. Son trajet : compteur en lecture seule.
      expect(find.byKey(const Key('trip-like-button')), findsOneWidget);
      expect(find.byKey(const Key('trip-like-count-readonly')), findsOneWidget);
      // Le signet reste sur les deux cartes, dans la ligne d'actions.
      expect(find.byType(FavoriteHeartButton), findsNWidgets(2));
    },
  );
}
