import 'package:bloc_test/bloc_test.dart';
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
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_carousel.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
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
      roles: ['ROLE_SENDER'],
      kycStatus: 'VERIFIED',
      status: 'ACTIVE',
    );

AnnouncementModel _ann(String id, {String travelerId = 'traveler-1'}) =>
    AnnouncementModel(
      id: id,
      travelerId: travelerId,
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 6, 15),
      availableKg: 10,
      totalKg: 20,
      pricePerKg: 7,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      traveler: TravelerProfile(
          id: travelerId, displayName: 'Sékou Ba', kiloPro: false),
    );

BidModel _bid({
  required String id,
  required String announcementId,
  String status = 'PENDING',
}) =>
    BidModel(
      id: id,
      announcementId: announcementId,
      senderId: 'uid-1',
      weightKg: 5,
      description: 'Test',
      status: status,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

Widget _wrap(
  Widget child, {
  BidState? bidState,
  AuthState? authState,
  FavoriteIdsCubit? favCubit,
}) {
  final bidBloc = _MockBidBloc();
  final authBloc = _MockAuthBloc();
  when(() => bidBloc.state).thenReturn(bidState ?? BidInitial());
  when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => authBloc.state)
      .thenReturn(authState ?? AuthAuthenticated(_makeUser()));
  when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());

  addTearDown(bidBloc.close);
  addTearDown(authBloc.close);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) =>
            Scaffold(body: SizedBox(height: 312, child: child)),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (_, __) => const Scaffold(key: Key('bids-route')),
      ),
    ],
  );

  final providers = <BlocProvider>[
    BlocProvider<BidBloc>.value(value: bidBloc),
    BlocProvider<AuthBloc>.value(value: authBloc),
    if (favCubit != null)
      BlocProvider<FavoriteIdsCubit>.value(value: favCubit),
  ];

  return MultiBlocProvider(
    providers: providers,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('1 — affiche un PageView avec autant de pages que d\'annonces',
      (tester) async {
    final anns = [_ann('a1'), _ann('a2'), _ann('a3')];
    await tester.pumpWidget(_wrap(NearMeCarousel(
      announcements: anns,
      userPosition: null,
      onSeeAll: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(TravelerCard), findsWidgets);
  });

  testWidgets(
      '2 — affiche le bouton "Voir les N annonces" avec le bon compteur',
      (tester) async {
    await tester.pumpWidget(_wrap(NearMeCarousel(
      announcements: [_ann('a1'), _ann('a2')],
      userPosition: null,
      onSeeAll: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Voir les 2 annonces'), findsOneWidget);
  });

  testWidgets('3 — affiche l\'empty state quand announcements est vide',
      (tester) async {
    await tester.pumpWidget(_wrap(NearMeCarousel(
      announcements: const [],
      userPosition: null,
      onSeeAll: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Aucun voyageur à proximité'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets(
      '4 — selectedAnnouncementId initialise le PageController sur la bonne page',
      (tester) async {
    final anns = [_ann('a1'), _ann('a2'), _ann('a3')];
    String? changed;

    await tester.pumpWidget(_wrap(NearMeCarousel(
      announcements: anns,
      userPosition: null,
      onSeeAll: () {},
      selectedAnnouncementId: 'a2', // should start at index 1
      onCardChanged: (id) => changed = id,
    )));
    await tester.pumpAndSettle();

    // Starting at a2 (page 1), swiping left must land on a3 (page 2)
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(changed, 'a3');
  });

  testWidgets(
      '5 — onCardChanged est appelé avec le bon id quand on swipe vers la page suivante',
      (tester) async {
    final anns = [_ann('a1'), _ann('a2')];
    String? captured;

    await tester.pumpWidget(_wrap(NearMeCarousel(
      announcements: anns,
      userPosition: null,
      onSeeAll: () {},
      onCardChanged: (id) => captured = id,
    )));
    await tester.pumpAndSettle();

    // 500 px > 50 % of the 800 px default test viewport → triggers page change
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(captured, 'a2');
  });

  testWidgets(
      '6 — tap sur une card sans bid invoque onTapCard avec l\'annonce',
      (tester) async {
    AnnouncementModel? tapped;

    await tester.pumpWidget(_wrap(NearMeCarousel(
      announcements: [_ann('a1')],
      userPosition: null,
      onSeeAll: () {},
      onTapCard: (a) => tapped = a,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('near-me-card-a1')));
    await tester.pumpAndSettle();

    expect(tapped?.id, 'a1');
  });

  testWidgets(
      '7 — tap sur une card avec bid PENDING navigue vers /bids/{id}',
      (tester) async {
    final bid = _bid(id: 'bid-1', announcementId: 'a1', status: 'PENDING');

    await tester.pumpWidget(_wrap(
      NearMeCarousel(
        announcements: [_ann('a1')],
        userPosition: null,
        onSeeAll: () {},
      ),
      bidState: BidListLoaded([bid]),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('near-me-card-a1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bids-route')), findsOneWidget);
  });

  testWidgets('8 — tap sur "Voir tout" invoque onSeeAll', (tester) async {
    bool called = false;

    await tester.pumpWidget(_wrap(NearMeCarousel(
      announcements: [_ann('a1')],
      userPosition: null,
      onSeeAll: () => called = true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('near-me-see-all-btn')));
    await tester.pumpAndSettle();

    expect(called, isTrue);
  });

  testWidgets(
      '9 — tap sur une card sans bid et sans onTapCard ouvre le bottom sheet',
      (tester) async {
    await tester.pumpWidget(_wrap(NearMeCarousel(
      announcements: [_ann('a1')],
      userPosition: null,
      onSeeAll: () {},
      // onTapCard intentionally omitted → fallback to showTravelerAnnouncementSheet
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('near-me-card-a1')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
  });

  // ── showFavorite gating ────────────────────────────────────────────────────

  testWidgets(
      '10 — non-owned card shows FavoriteHeartButton when FavoriteIdsCubit is provided',
      (tester) async {
    final repo = _MockFavoriteRepository();
    final cubit = FavoriteIdsCubit(repo)..emitSeed(trips: {}, requests: {});
    // _ann('a1') has travelerId='traveler-1'; auth user is 'uid-1' → not owner
    await tester.pumpWidget(_wrap(
      NearMeCarousel(
        announcements: [_ann('a1')],
        userPosition: null,
        onSeeAll: () {},
      ),
      favCubit: cubit,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FavoriteHeartButton), findsOneWidget);
  });

  testWidgets(
      '11 — owned card does NOT show FavoriteHeartButton even when FavoriteIdsCubit is provided',
      (tester) async {
    final repo = _MockFavoriteRepository();
    final cubit = FavoriteIdsCubit(repo)..emitSeed(trips: {}, requests: {});
    // _ann with travelerId='uid-1' matches the authenticated user → isOwn=true
    await tester.pumpWidget(_wrap(
      NearMeCarousel(
        announcements: [_ann('a1', travelerId: 'uid-1')],
        userPosition: null,
        onSeeAll: () {},
      ),
      favCubit: cubit,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FavoriteHeartButton), findsNothing);
  });
}
