import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/constants/cities.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/route_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockFavoriteRepository extends Mock implements FavoriteRepository {}

UserModel _makeUser({String id = 'uid-1'}) => UserModel(
  id: id,
  phoneNumber: '+33600000000',
  firstName: 'Test',
  lastName: 'User',
  roles: const ['ROLE_SENDER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

AnnouncementModel _ann(
  String dep,
  String arr, {
  String id = 'a1',
  String travelerId = 't1',
}) => AnnouncementModel(
  id: id,
  travelerId: travelerId,
  departureCity: dep,
  arrivalCity: arr,
  departureDate: DateTime(2026, 6, 15),
  availableKg: 8,
  totalKg: 8,
  pricePerKg: 12,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
  traveler: TravelerProfile(id: travelerId, displayName: 'Sékou Ba'),
);

final _paris = CityConstants.findById('paris')!;
final _dakar = CityConstants.findById('dakar')!;
final _abidjan = CityConstants.findById('abidjan')!;

Widget _wrap(Widget child, {AuthState? authState, FavoriteIdsCubit? favCubit}) {
  final bidBloc = _MockBidBloc();
  final authBloc = _MockAuthBloc();
  when(() => bidBloc.state).thenReturn(BidInitial());
  when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());
  when(
    () => authBloc.state,
  ).thenReturn(authState ?? AuthAuthenticated(_makeUser()));
  when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());

  addTearDown(bidBloc.close);
  addTearDown(authBloc.close);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: child),
      ),
      GoRoute(path: '/search/:id', builder: (_, _) => const Scaffold()),
    ],
  );

  final providers = <BlocProvider>[
    BlocProvider<BidBloc>.value(value: bidBloc),
    BlocProvider<AuthBloc>.value(value: authBloc),
    if (favCubit != null) BlocProvider<FavoriteIdsCubit>.value(value: favCubit),
  ];

  return MultiBlocProvider(
    providers: providers,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('RouteBottomSheet', () {
    final announcements = [
      _ann('Paris', 'Dakar'),
      _ann('Paris', 'Dakar', id: 'a2'),
      _ann('Paris', 'Abidjan', id: 'a3'),
      _ann('Lyon', 'Dakar', id: 'a4'),
    ];

    testWidgets('ExactRouteFilter shows only Paris→Dakar trips', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RouteBottomSheet(
            announcements: announcements,
            filter: ExactRouteFilter(_paris, _dakar),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Paris → Dakar'), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a1')), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a2')), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a4')), findsNothing);
    });

    testWidgets('DepartureCityFilter shows trips from Paris only', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RouteBottomSheet(
            announcements: announcements,
            filter: DepartureCityFilter(_paris),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Départs depuis Paris'), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a1')), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a3')), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a4')), findsNothing);
    });

    testWidgets('ArrivalCityFilter shows trips to Dakar only', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RouteBottomSheet(
            announcements: announcements,
            filter: ArrivalCityFilter(_dakar),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Arrivées à Dakar'), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a1')), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a4')), findsOneWidget);
      expect(find.byKey(const Key('traveler-card-a3')), findsNothing);
    });

    testWidgets('ExactRouteFilter Paris→Abidjan shows a3 only', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RouteBottomSheet(
            announcements: announcements,
            filter: ExactRouteFilter(_paris, _abidjan),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('traveler-card-a3')), findsOneWidget);
    });

    testWidgets('shows empty message when filter matches nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RouteBottomSheet(
            announcements: const [],
            filter: ExactRouteFilter(_paris, _dakar),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Aucun trajet disponible sur cette route'),
        findsOneWidget,
      );
    });
  });

  // ── showFavorite gating ────────────────────────────────────────────────────

  group('RouteBottomSheet – showFavorite', () {
    testWidgets(
      'non-owned card shows FavoriteHeartButton when FavoriteIdsCubit is provided',
      (tester) async {
        final repo = _MockFavoriteRepository();
        final cubit = FavoriteIdsCubit(repo)..emitSeed(trips: {}, requests: {});
        // travelerId='t1', authenticated user='uid-1' → not owner
        await tester.pumpWidget(
          _wrap(
            RouteBottomSheet(
              announcements: [_ann('Paris', 'Dakar')],
              filter: ExactRouteFilter(_paris, _dakar),
            ),
            favCubit: cubit,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FavoriteHeartButton), findsOneWidget);
      },
    );

    testWidgets(
      'owned card does NOT show FavoriteHeartButton even when FavoriteIdsCubit is provided',
      (tester) async {
        final repo = _MockFavoriteRepository();
        final cubit = FavoriteIdsCubit(repo)..emitSeed(trips: {}, requests: {});
        // travelerId='uid-1' matches auth user → isOwn=true → showFavorite:false
        await tester.pumpWidget(
          _wrap(
            RouteBottomSheet(
              announcements: [_ann('Paris', 'Dakar', travelerId: 'uid-1')],
              filter: ExactRouteFilter(_paris, _dakar),
            ),
            favCubit: cubit,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FavoriteHeartButton), findsNothing);
      },
    );
  });
}
