import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/bloc/profile_public_bloc.dart';
import 'package:dony/features/profile/bloc/profile_public_event.dart';
import 'package:dony/features/profile/bloc/profile_public_state.dart';
import 'package:dony/features/profile/data/models/profile_public_model.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_bloc.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_event.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockProfilePublicBloc
    extends MockBloc<ProfilePublicEvent, ProfilePublicState>
    implements ProfilePublicBloc {}

class MockTravelerSubscribeBloc
    extends MockBloc<TravelerSubscribeEvent, TravelerSubscribeState>
    implements TravelerSubscribeBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class FakeProfilePublicEvent extends Fake implements ProfilePublicEvent {}

class FakeTravelerSubscribeEvent extends Fake
    implements TravelerSubscribeEvent {}

class FakeAuthEvent extends Fake implements AuthEvent {}

// ─── Test data ───────────────────────────────────────────────────────────────

const _userId = 'user-1';
const _currentUserId = 'current-user-99';

const _profile = ProfilePublicModel(
  userId: _userId,
  displayName: 'Fatou Diallo',
  kycVerified: true,
  isProAccount: false,
  isKiloPro: false,
  completedBidsCount: 12,
  averageRating: 4.8,
  ratingCount: 7,
  memberSince: 'mars 2025',
  badges: ['Super Expéditeur'],
);

ProfilePublicModel profileWith({
  String? bio,
  List<String> languages = const [],
  String? transportMode,
}) {
  return ProfilePublicModel(
    userId: _userId,
    displayName: 'Fatou Diallo',
    kycVerified: true,
    isProAccount: false,
    isKiloPro: false,
    completedBidsCount: 12,
    averageRating: 4.8,
    ratingCount: 7,
    memberSince: 'mars 2025',
    badges: const [],
    bio: bio,
    languages: languages,
    transportMode: transportMode,
  );
}

final _ratingSummary = RatingSummary(
  averageRating: 4.8,
  ratingCount: 7,
  distribution: const {1: 0, 2: 0, 3: 0, 4: 2, 5: 5},
  ratings: [
    RatingItem(
      stars: 5,
      comment: 'Parfait !',
      createdAt: DateTime.utc(2026, 3),
      excluded: false,
      authorName: 'Moussa Koné',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
    ),
  ],
  page: 0,
  totalPages: 1,
);

// ─── Helper: minimal UserModel ────────────────────────────────────────────────

UserModel _fakeUser(String id) => UserModel(
      id: id,
      phoneNumber: '+33600000001',
      roles: const ['ROLE_SENDER'],
      kycStatus: 'APPROVED',
      status: 'ACTIVE',
    );

// ─── Widget builders ──────────────────────────────────────────────────────────

/// Builds a full test app with all 3 blocs injected.
/// [showSubscribe] controls ProfilePublicScreen.showSubscribe.
/// [screenUserId] is the userId passed to ProfilePublicScreen (the profile being viewed).
/// [authUserId] is the id of the logged-in user (from AuthBloc).
Widget _wrap(
  MockProfilePublicBloc profileBloc, {
  MockTravelerSubscribeBloc? subscribeBloc,
  MockAuthBloc? authBloc,
  bool showSubscribe = false,
  String screenUserId = _userId,
  String authUserId = _currentUserId,
}) {
  // Only create default mocks when the caller didn't provide one.
  // When the caller provides their own bloc, they are responsible for stubbing
  // .state and .stream — don't override them here.
  final MockTravelerSubscribeBloc subBloc;
  if (subscribeBloc != null) {
    subBloc = subscribeBloc;
  } else {
    subBloc = MockTravelerSubscribeBloc();
    when(() => subBloc.state).thenReturn(const TravelerSubscribeState());
    when(() => subBloc.stream)
        .thenAnswer((_) => Stream.value(const TravelerSubscribeState()));
  }

  final MockAuthBloc aBloc;
  if (authBloc != null) {
    aBloc = authBloc;
  } else {
    aBloc = MockAuthBloc();
    when(() => aBloc.state)
        .thenReturn(AuthAuthenticated(_fakeUser(authUserId)));
    when(() => aBloc.stream).thenAnswer(
        (_) => Stream.value(AuthAuthenticated(_fakeUser(authUserId))));
  }

  return MultiBlocProvider(
    providers: [
      BlocProvider<ProfilePublicBloc>.value(value: profileBloc),
      BlocProvider<TravelerSubscribeBloc>.value(value: subBloc),
      BlocProvider<AuthBloc>.value(value: aBloc),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => ProfilePublicScreen(
              userId: screenUserId,
              showSubscribe: showSubscribe,
            ),
          ),
          GoRoute(
            path: '/profile/reviews',
            builder: (_, _) => const Scaffold(body: Text('Reviews')),
          ),
        ],
      ),
    ),
  );
}

Widget _wrapLoaded({
  required ProfilePublicModel profile,
  MockTravelerSubscribeBloc? subscribeBloc,
  MockAuthBloc? authBloc,
  bool showSubscribe = false,
  String screenUserId = _userId,
  String authUserId = _currentUserId,
}) {
  final bloc = MockProfilePublicBloc();
  final loadedState = ProfilePublicLoaded(profile: profile, recentRatings: _ratingSummary);
  when(() => bloc.state).thenReturn(loadedState);
  when(() => bloc.stream).thenAnswer((_) => Stream.value(loadedState));
  return _wrap(
    bloc,
    subscribeBloc: subscribeBloc,
    authBloc: authBloc,
    showSubscribe: showSubscribe,
    screenUserId: screenUserId,
    authUserId: authUserId,
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late MockProfilePublicBloc bloc;

  setUpAll(() {
    registerFallbackValue(FakeProfilePublicEvent());
    registerFallbackValue(FakeTravelerSubscribeEvent());
    registerFallbackValue(FakeAuthEvent());
  });

  setUp(() {
    bloc = MockProfilePublicBloc();
    when(() => bloc.state).thenReturn(const ProfilePublicInitial());
  });

  // ── 1. Loading ────────────────────────────────────────────────────────────

  testWidgets('shows CircularProgressIndicator when loading', (tester) async {
    when(() => bloc.state).thenReturn(const ProfilePublicLoading());

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // ── 2. Title — contextual ─────────────────────────────────────────────────

  testWidgets(
      'title is "Ce que les autres voient" when viewing own profile',
      (tester) async {
    // screenUserId == authUserId → own profile
    when(() => bloc.state).thenReturn(const ProfilePublicLoading());

    await tester.pumpWidget(
      _wrap(
        bloc,
        screenUserId: _userId,
        authUserId: _userId, // same → own profile
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Ce que les autres voient'), findsOneWidget);
  });

  testWidgets(
      'title is displayName when viewing another user (loaded)',
      (tester) async {
    // Profile with displayName 'abou D.' viewed by a different user
    const otherProfile = ProfilePublicModel(
      userId: _userId,
      displayName: 'abou D.',
      kycVerified: false,
      isProAccount: false,
      isKiloPro: false,
      completedBidsCount: 5,
      averageRating: 0,
      ratingCount: 0,
      memberSince: 'janv. 2025',
      badges: [],
    );
    final loadedState = ProfilePublicLoaded(
      profile: otherProfile,
      recentRatings: RatingSummary(
        averageRating: 0,
        ratingCount: 0,
        distribution: const {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        ratings: const [],
        page: 0,
        totalPages: 0,
      ),
    );
    when(() => bloc.state).thenReturn(loadedState);
    when(() => bloc.stream).thenAnswer((_) => Stream.value(loadedState));

    await tester.pumpWidget(
      _wrap(
        bloc,
        screenUserId: _userId, // viewing user-1
        authUserId: _currentUserId, // logged-in = current-user-99 (different)
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('abou D.'), findsWidgets); // in app bar
  });

  testWidgets(
      'title is "Profil" when viewing another user while loading',
      (tester) async {
    when(() => bloc.state).thenReturn(const ProfilePublicLoading());

    await tester.pumpWidget(
      _wrap(
        bloc,
        screenUserId: _userId, // viewing user-1
        authUserId: _currentUserId, // logged-in = different
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Profil'), findsOneWidget);
  });

  // ── 3. Display name ───────────────────────────────────────────────────────

  testWidgets('shows displayName when loaded', (tester) async {
    when(() => bloc.state).thenReturn(
      ProfilePublicLoaded(profile: _profile, recentRatings: _ratingSummary),
    );

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    // displayName appears in the hero band; when viewing another user it also
    // appears in the app bar title — so we just verify it is present.
    expect(find.text('Fatou Diallo'), findsWidgets);
  });

  testWidgets('hero has no blue gradient background', (tester) async {
    await tester.pumpWidget(_wrapLoaded(profile: _profile));
    await tester.pump(const Duration(milliseconds: 600));

    final containers = tester.widgetList<Container>(find.byType(Container));
    final hasBlueHeroGradient = containers.any((c) {
      final decoration = c.decoration;
      if (decoration is! BoxDecoration || decoration.gradient is! LinearGradient) {
        return false;
      }
      final colors = (decoration.gradient! as LinearGradient).colors;
      return colors.contains(DonyColors.blue500);
    });
    expect(hasBlueHeroGradient, isFalse);
  });

  testWidgets('no sticky bar container above the scroll area', (tester) async {
    final subBloc = MockTravelerSubscribeBloc();
    const subState = TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: false,
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        subscribeBloc: subBloc,
        showSubscribe: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // The Scaffold body must be the loaded content directly — no
    // Column([Expanded(body), stickyBar]) wrapper anymore — and the
    // scrollable content (CustomScrollView) is present in the tree.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.body, isNot(isA<Column>()));
    expect(find.byType(CustomScrollView), findsOneWidget);
  });

  // ── 4. KYC badge ─────────────────────────────────────────────────────────

  testWidgets('shows KYC badge when verified', (tester) async {
    when(() => bloc.state).thenReturn(
      ProfilePublicLoaded(profile: _profile, recentRatings: _ratingSummary),
    );

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('✓ Vérifié'), findsOneWidget);
  });

  // ── 5. Error + retry ──────────────────────────────────────────────────────

  testWidgets('shows retry button on error', (tester) async {
    when(() => bloc.state)
        .thenReturn(const ProfilePublicError(message: 'Serveur indisponible'));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('retry button dispatches ProfilePublicRequested', (tester) async {
    when(() => bloc.state)
        .thenReturn(const ProfilePublicError(message: 'Serveur indisponible'));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Réessayer'));
    verify(() => bloc.add(any(that: isA<ProfilePublicRequested>()))).called(1);
  });

  // ── 6. À propos + langues ─────────────────────────────────────────────────

  testWidgets('profil public affiche À propos + langues si présents',
      (tester) async {
    await tester.pumpWidget(
      _wrapLoaded(
        profile: profileWith(
          bio: 'Hello',
          languages: ['FR'],
          transportMode: 'AVION',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('À PROPOS', skipOffstage: false), findsOneWidget);
    expect(find.text('Hello', skipOffstage: false), findsOneWidget);
    expect(find.text('LANGUES', skipOffstage: false), findsOneWidget);
  });

  testWidgets('profil public masque À propos/langues si absents',
      (tester) async {
    await tester.pumpWidget(
      _wrapLoaded(profile: profileWith()),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('À PROPOS', skipOffstage: false), findsNothing);
    expect(find.text('LANGUES', skipOffstage: false), findsNothing);
    expect(find.text('TRANSPORT', skipOffstage: false), findsNothing);
  });

  testWidgets('profil public affiche le bon label de transport', (tester) async {
    await tester.pumpWidget(
      _wrapLoaded(
        profile: profileWith(
          languages: [],
          transportMode: 'VOITURE',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('🚗 Voiture', skipOffstage: false), findsOneWidget);
    expect(find.text('TRANSPORT', skipOffstage: false), findsOneWidget);
    expect(find.text('LANGUES', skipOffstage: false), findsNothing);
  });

  // ── 7. Stats row: 3 cols, no "Membre depuis" stat ────────────────────────

  testWidgets('stats row shows Note, Livraisons, Répond en (3 columns)',
      (tester) async {
    await tester.pumpWidget(_wrapLoaded(profile: _profile));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Note', skipOffstage: false), findsOneWidget);
    expect(find.text('Livraisons', skipOffstage: false), findsOneWidget);
    expect(find.text('Répond en', skipOffstage: false), findsOneWidget);
    // "Membre depuis" should NOT appear as a stat column
    expect(find.text('Membre depuis', skipOffstage: false), findsNothing);
  });

  // ── 8. Enriched reviews: author name + corridor ───────────────────────────

  testWidgets('review card shows author name', (tester) async {
    await tester.pumpWidget(_wrapLoaded(profile: _profile));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Moussa Koné', skipOffstage: false), findsOneWidget);
  });

  testWidgets('review card shows corridor chip when both cities present',
      (tester) async {
    await tester.pumpWidget(_wrapLoaded(profile: _profile));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Paris → Dakar', skipOffstage: false), findsOneWidget);
  });

  testWidgets('review card shows fallback author name when null', (tester) async {
    final summaryNoAuthor = RatingSummary(
      averageRating: 4.0,
      ratingCount: 1,
      distribution: const {1: 0, 2: 0, 3: 0, 4: 1, 5: 0},
      ratings: [
        RatingItem(
          stars: 4,
          createdAt: DateTime.utc(2026, 1),
          excluded: false,
          // authorName is null — fallback to "Utilisateur"
        ),
      ],
      page: 0,
      totalPages: 1,
    );
    final b = MockProfilePublicBloc();
    when(() => b.state).thenReturn(
      ProfilePublicLoaded(profile: _profile, recentRatings: summaryNoAuthor),
    );
    await tester.pumpWidget(_wrap(b));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Utilisateur', skipOffstage: false), findsOneWidget);
  });

  testWidgets('review card hides corridor chip when cities absent',
      (tester) async {
    final summaryNoCorridor = RatingSummary(
      averageRating: 5.0,
      ratingCount: 1,
      distribution: const {1: 0, 2: 0, 3: 0, 4: 0, 5: 1},
      ratings: [
        RatingItem(
          stars: 5,
          createdAt: DateTime.utc(2026, 2),
          excluded: false,
          authorName: 'Jean Paul',
          // no departure/arrival
        ),
      ],
      page: 0,
      totalPages: 1,
    );
    final b = MockProfilePublicBloc();
    when(() => b.state).thenReturn(
      ProfilePublicLoaded(
          profile: _profile, recentRatings: summaryNoCorridor),
    );
    await tester.pumpWidget(_wrap(b));
    await tester.pump(const Duration(milliseconds: 600));

    // Corridor text "→" should not appear
    expect(
        find.textContaining('→', skipOffstage: false), findsNothing);
  });

  // ── 9. Subscribe action — compact, in-hero ────────────────────────────────

  testWidgets(
      'subscribe button appears when showSubscribe=true and userId != currentUser',
      (tester) async {
    final subBloc = MockTravelerSubscribeBloc();
    const subState = TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: false,
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        subscribeBloc: subBloc,
        showSubscribe: true,
        screenUserId: _userId,
        authUserId: _currentUserId,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text("S'abonner"), findsOneWidget);
  });

  testWidgets('subscribe button absent when showSubscribe=false', (tester) async {
    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        showSubscribe: false,
        screenUserId: _userId,
        authUserId: _currentUserId,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text("S'abonner"), findsNothing);
    expect(find.text('Abonné ✓'), findsNothing);
  });

  testWidgets('subscribe button absent when viewing own profile', (tester) async {
    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        showSubscribe: true,
        screenUserId: _userId,
        authUserId: _userId, // same → own profile
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text("S'abonner"), findsNothing);
    expect(find.text('Abonné ✓'), findsNothing);
  });

  testWidgets('shows "Abonné ✓" + bell icon when already subscribed',
      (tester) async {
    final subBloc = MockTravelerSubscribeBloc();
    const subState = TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: true,
      pushEnabled: true,
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        subscribeBloc: subBloc,
        showSubscribe: true,
        screenUserId: _userId,
        authUserId: _currentUserId,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Abonné ✓'), findsOneWidget);
    expect(find.text("S'abonner"), findsNothing);
    expect(find.byTooltip('Désactiver les notifications'), findsOneWidget);
  });

  testWidgets('tapping subscribe dispatches SubscribePressed', (tester) async {
    final subBloc = MockTravelerSubscribeBloc();
    const subState = TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: false,
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        subscribeBloc: subBloc,
        showSubscribe: true,
        screenUserId: _userId,
        authUserId: _currentUserId,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text("S'abonner"));
    verify(() => subBloc.add(const SubscribePressed())).called(1);
  });

  testWidgets('tapping bell dispatches TogglePushPressed(!pushEnabled)',
      (tester) async {
    final subBloc = MockTravelerSubscribeBloc();
    const subState = TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: true,
      pushEnabled: true,
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        subscribeBloc: subBloc,
        showSubscribe: true,
        screenUserId: _userId,
        authUserId: _currentUserId,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byTooltip('Désactiver les notifications'));

    // TogglePushPressed doesn't implement ==, capture and verify the field
    // (same pattern as HubTogglePush in traveler_profile_hub_screen_test.dart).
    final captured = verify(() => subBloc.add(captureAny())).captured;
    final toggle = captured.whereType<TogglePushPressed>().toList();
    expect(toggle, hasLength(1));
    expect(toggle.single.enabled, isFalse);
  });

  testWidgets('tapping "Abonné ✓" opens confirm dialog, confirming unsubscribes',
      (tester) async {
    final subBloc = MockTravelerSubscribeBloc();
    const subState = TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: true,
      pushEnabled: false,
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        subscribeBloc: subBloc,
        showSubscribe: true,
        screenUserId: _userId,
        authUserId: _currentUserId,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Abonné ✓'));
    await tester.pumpAndSettle();

    expect(find.text('Se désabonner ?'), findsOneWidget);

    await tester.tap(find.text('Se désabonner'));
    await tester.pumpAndSettle();

    verify(() => subBloc.add(const UnsubscribePressed())).called(1);
  });
}
