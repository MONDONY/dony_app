import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
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
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockProfilePublicBloc
    extends MockBloc<ProfilePublicEvent, ProfilePublicState>
    implements ProfilePublicBloc {}

class MockTravelerSubscribeBloc
    extends MockBloc<TravelerSubscribeEvent, TravelerSubscribeState>
    implements TravelerSubscribeBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

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
  );
}

const _profileOneReview = ProfilePublicModel(
  userId: _userId,
  displayName: 'Fatou Diallo',
  kycVerified: false,
  isProAccount: false,
  isKiloPro: false,
  completedBidsCount: 3,
  averageRating: 4.5,
  ratingCount: 1,
  memberSince: 'mars 2025',
  badges: [],
);

const _profileTwelveReviews = ProfilePublicModel(
  userId: _userId,
  displayName: 'Fatou Diallo',
  kycVerified: false,
  isProAccount: false,
  isKiloPro: false,
  completedBidsCount: 3,
  averageRating: 4.5,
  ratingCount: 12,
  memberSince: 'mars 2025',
  badges: [],
);

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
/// [screenUserId] is the userId passed to ProfilePublicScreen (the profile being viewed).
/// [authUserId] is the id of the logged-in user (from AuthBloc).
Widget _wrap(
  MockProfilePublicBloc profileBloc, {
  MockTravelerSubscribeBloc? subscribeBloc,
  MockAuthBloc? authBloc,
  String? screenUserId = _userId,
  String authUserId = _currentUserId,
}) {
  // Only create default mocks when the caller didn't provide one.
  // When the caller provides their own bloc, they are responsible for stubbing
  // .state and .stream — don't override them here.
  final MockTravelerSubscribeBloc subBloc;
  if (subscribeBloc != null) {
    subBloc = subscribeBloc;
  } else {
    // Statut déjà chargé : le bouton apparaît sur tout profil d'un autre, un
    // état initial (spinner infini) bloquerait les pumpAndSettle.
    const ready = TravelerSubscribeState(status: TravelerSubscribeStatus.ready);
    subBloc = MockTravelerSubscribeBloc();
    when(() => subBloc.state).thenReturn(ready);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(ready));
  }

  final MockAuthBloc aBloc;
  if (authBloc != null) {
    aBloc = authBloc;
  } else {
    aBloc = MockAuthBloc();
    when(
      () => aBloc.state,
    ).thenReturn(AuthAuthenticated(_fakeUser(authUserId)));
    when(
      () => aBloc.stream,
    ).thenAnswer((_) => Stream.value(AuthAuthenticated(_fakeUser(authUserId))));
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
            builder: (_, _) => ProfilePublicScreen(userId: screenUserId),
          ),
          GoRoute(
            path: '/profile/reviews',
            builder: (_, _) => const Scaffold(body: Text('Reviews')),
          ),
          GoRoute(
            path: '/settings/report-incident',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return Scaffold(body: Text('Reported: ${extra?['targetId']}'));
            },
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
  String? screenUserId = _userId,
  String authUserId = _currentUserId,
}) {
  final bloc = MockProfilePublicBloc();
  final loadedState = ProfilePublicLoaded(
    profile: profile,
    recentRatings: _ratingSummary,
  );
  when(() => bloc.state).thenReturn(loadedState);
  when(() => bloc.stream).thenAnswer((_) => Stream.value(loadedState));
  return _wrap(
    bloc,
    subscribeBloc: subscribeBloc,
    authBloc: authBloc,
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

  testWidgets('shows skeleton when loading', (tester) async {
    when(() => bloc.state).thenReturn(const ProfilePublicLoading());

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(DonyDetailSkeleton), findsOneWidget);
  });

  // ── 2. Title — contextual ─────────────────────────────────────────────────

  testWidgets('title is "Ce que les autres voient" when viewing own profile', (
    tester,
  ) async {
    // screenUserId == authUserId → own profile
    when(() => bloc.state).thenReturn(const ProfilePublicLoading());

    await tester.pumpWidget(
      _wrap(
        bloc,
        authUserId: _userId, // same → own profile
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Ce que les autres voient'), findsOneWidget);
  });

  testWidgets('title is displayName when viewing another user (loaded)', (
    tester,
  ) async {
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
    const loadedState = ProfilePublicLoaded(
      profile: otherProfile,
      recentRatings: RatingSummary(
        averageRating: 0,
        ratingCount: 0,
        distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        ratings: [],
        page: 0,
        totalPages: 0,
      ),
    );
    when(() => bloc.state).thenReturn(loadedState);
    when(() => bloc.stream).thenAnswer((_) => Stream.value(loadedState));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('abou D.'), findsWidgets); // in app bar
  });

  testWidgets('title is "Profil" when viewing another user while loading', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ProfilePublicLoading());

    await tester.pumpWidget(_wrap(bloc));
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

  // FLUTTER-8D : la vignette de 64 px ne laissait pas voir le visage.
  testWidgets('photo de profil : un toucher l\'ouvre en grand, zoomable', (
    tester,
  ) async {
    const withPhoto = ProfilePublicModel(
      userId: _userId,
      displayName: 'Fatou Diallo',
      kycVerified: true,
      isProAccount: false,
      isKiloPro: false,
      completedBidsCount: 12,
      averageRating: 4.8,
      ratingCount: 7,
      memberSince: 'mars 2025',
      badges: [],
      avatarUrl: 'https://cdn.example.com/avatars/fatou.jpg',
    );
    await tester.pumpWidget(_wrapLoaded(profile: withPhoto));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == 'Voir la photo de profil',
      ),
      findsOneWidget,
    );
    expect(find.byType(InteractiveViewer), findsNothing);

    await tester.tap(find.byKey(const Key('profile-public-avatar')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('sans photo : initiales, rien à agrandir', (tester) async {
    await tester.pumpWidget(_wrapLoaded(profile: _profile));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const Key('profile-public-avatar')), findsNothing);
    expect(find.text('FD'), findsOneWidget);
  });

  // FLUTTER-4H : vérifications et pays de résidence.
  testWidgets('section Vérifications : téléphone, e-mail, pièce d\'identité', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      _wrapLoaded(
        profile: const ProfilePublicModel(
          userId: _userId,
          displayName: 'Fatou Diallo',
          kycVerified: true,
          isProAccount: false,
          isKiloPro: false,
          completedBidsCount: 12,
          averageRating: 4.8,
          ratingCount: 7,
          memberSince: 'mars 2025',
          badges: [],
          phoneVerified: true,
          residenceCountry: 'FR',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const Key('profile-verifications')), findsOneWidget);
    expect(find.text('Numéro de téléphone'), findsOneWidget);
    expect(find.text('Adresse e-mail'), findsOneWidget);
    expect(find.text("Pièce d'identité"), findsOneWidget);
    // Téléphone et identité vérifiés, e-mail non.
    expect(find.text('Non vérifié'), findsOneWidget);
    expect(find.text('Réside en France'), findsOneWidget);
  });

  testWidgets('dernière connexion et temps de réponse mesuré (4H partie 2)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      _wrapLoaded(
        profile: const ProfilePublicModel(
          userId: _userId,
          displayName: 'Fatou Diallo',
          kycVerified: true,
          isProAccount: false,
          isKiloPro: false,
          completedBidsCount: 12,
          averageRating: 4.8,
          ratingCount: 7,
          memberSince: 'mars 2025',
          badges: [],
          measuredResponseMinutes: 130,
          lastSeenDaysAgo: 1,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Vu hier'), findsOneWidget);
    expect(find.byKey(const Key('profile-response-time')), findsOneWidget);
    expect(find.text('3 h'), findsOneWidget);
    expect(find.text('Réponse'), findsOneWidget);
  });

  testWidgets('sans mesure ni dernière connexion : rien d\'inventé', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_wrapLoaded(profile: _profile));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const Key('profile-last-seen')), findsNothing);
    expect(find.byKey(const Key('profile-response-time')), findsNothing);
  });

  test('libellés : dernière connexion au jour près, réponse arrondie', () {
    final l = lookupAppLocalizations(const Locale('fr'));
    expect(lastSeenLabel(l, 0), "Vu aujourd'hui");
    expect(lastSeenLabel(l, 1), 'Vu hier');
    expect(lastSeenLabel(l, 12), 'Vu il y a 12 jours');
    expect(lastSeenLabel(l, 45), "Vu il y a plus d'un mois");
    expect(responseTimeLabel(l, 20), '< 1 h');
    expect(responseTimeLabel(l, 61), '2 h');
    expect(responseTimeLabel(l, 60 * 30), '2 j');
  });

  testWidgets('pas de pays de résidence sans consentement', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_wrapLoaded(profile: _profile));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const Key('profile-residence-country')), findsNothing);
  });

  testWidgets('hero has no blue gradient background', (tester) async {
    await tester.pumpWidget(_wrapLoaded(profile: _profile));
    await tester.pump(const Duration(milliseconds: 600));

    // Le bouton « S'abonner » (présent sur tout profil d'un autre) porte son
    // propre dégradé de marque : seul le fond du hero est visé ici.
    final buttonContainers = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(DonyButton),
            matching: find.byType(Container),
          ),
        )
        .toSet();
    final containers = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => !buttonContainers.contains(c));
    final hasBlueHeroGradient = containers.any((c) {
      final decoration = c.decoration;
      if (decoration is! BoxDecoration ||
          decoration.gradient is! LinearGradient) {
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
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

    await tester.pumpWidget(
      _wrapLoaded(profile: _profile, subscribeBloc: subBloc),
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
    when(() => bloc.state).thenReturn(
      const ProfilePublicError(error: NetworkException('Serveur indisponible')),
    );

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('retry button dispatches ProfilePublicRequested', (tester) async {
    when(() => bloc.state).thenReturn(
      const ProfilePublicError(error: NetworkException('Serveur indisponible')),
    );

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Réessayer'));
    verify(() => bloc.add(any(that: isA<ProfilePublicRequested>()))).called(1);
  });

  testWidgets(
    'anglais : erreur réseau affiche le texte du catalogue, jamais le '
    'message brut',
    (tester) async {
      useEnglish();
      when(() => bloc.state).thenReturn(
        const ProfilePublicError(
          error: NetworkException('raw technical detail'),
        ),
      );

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.text('Something went wrong. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.text('raw technical detail'), findsNothing);
    },
  );

  // ── 6. À propos + langues ─────────────────────────────────────────────────

  testWidgets('profil public affiche À propos + langues si présents', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapLoaded(
        profile: profileWith(bio: 'Hello', languages: ['FR']),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('À PROPOS', skipOffstage: false), findsOneWidget);
    expect(find.text('Hello', skipOffstage: false), findsOneWidget);
    expect(find.text('LANGUES', skipOffstage: false), findsOneWidget);
  });

  testWidgets('profil public masque À propos/langues si absents', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapLoaded(profile: profileWith()));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('À PROPOS', skipOffstage: false), findsNothing);
    expect(find.text('LANGUES', skipOffstage: false), findsNothing);
  });

  testWidgets(
    'le mode de transport a quitté la fiche publique : il appartenait au '
    'profil, pas au trajet, et n\'apprenait rien sur le voyageur',
    (tester) async {
      await tester.pumpWidget(
        _wrapLoaded(profile: profileWith(languages: ['FR'])),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('TRANSPORT', skipOffstage: false), findsNothing);
      expect(find.text('LANGUES', skipOffstage: false), findsOneWidget);
    },
  );

  testWidgets('anglais : les langues parlées du profil public sont traduites', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(
      _wrapLoaded(
        profile: profileWith(languages: ['Français', 'Anglais', 'Wolof']),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('French', skipOffstage: false), findsOneWidget);
    expect(find.text('English', skipOffstage: false), findsOneWidget);
    expect(find.text('Wolof', skipOffstage: false), findsOneWidget);
    expect(find.text('Français', skipOffstage: false), findsNothing);
  });

  // ── 7. Stats row: 2 cols, no "Répond en" / "Membre depuis" stat ──────────

  testWidgets('stats row shows Note and Livraisons only (2 columns)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapLoaded(profile: _profile));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Note', skipOffstage: false), findsOneWidget);
    expect(find.text('Livraisons', skipOffstage: false), findsOneWidget);
    expect(find.text('Répond en', skipOffstage: false), findsNothing);
    expect(find.text('Membre depuis', skipOffstage: false), findsNothing);
  });

  // ── 8. Enriched reviews: author name + corridor ───────────────────────────

  testWidgets('review card shows author name', (tester) async {
    await tester.pumpWidget(_wrapLoaded(profile: _profile));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Moussa Koné', skipOffstage: false), findsOneWidget);
  });

  testWidgets('review card shows corridor chip when both cities present', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapLoaded(profile: _profile));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Paris → Dakar', skipOffstage: false), findsOneWidget);
  });

  testWidgets('review card shows fallback author name when null', (
    tester,
  ) async {
    final summaryNoAuthor = RatingSummary(
      averageRating: 4.0,
      ratingCount: 1,
      distribution: const {1: 0, 2: 0, 3: 0, 4: 1, 5: 0},
      ratings: [
        RatingItem(
          stars: 4,
          createdAt: DateTime.utc(2026),
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

  testWidgets('review card hides corridor chip when cities absent', (
    tester,
  ) async {
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
      ProfilePublicLoaded(profile: _profile, recentRatings: summaryNoCorridor),
    );
    await tester.pumpWidget(_wrap(b));
    await tester.pump(const Duration(milliseconds: 600));

    // Corridor text "→" should not appear
    expect(find.textContaining('→', skipOffstage: false), findsNothing);
  });

  // ── 9. Subscribe action — compact, in-hero ────────────────────────────────

  // Sentry FLUTTER-DB : le bouton dépend du seul profil consulté, plus d'un
  // drapeau de l'écran appelant. Tout profil qui n'est pas le mien l'affiche.

  MockTravelerSubscribeBloc readySubBloc() {
    final subBloc = MockTravelerSubscribeBloc();
    const subState = TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));
    return subBloc;
  }

  List<LoadSubscribeStatus> loadCalls(MockTravelerSubscribeBloc subBloc) {
    final calls = verify(
      () => subBloc.add(captureAny()),
    ).captured.whereType<LoadSubscribeStatus>().toList();
    return calls;
  }

  testWidgets(
    "profil d'un autre ouvert sans drapeau (chat, fil, réception) → bouton",
    (tester) async {
      final subBloc = readySubBloc();

      // Les appelants ne passent plus qu'un userId, comme l'en-tête du chat.
      await tester.pumpWidget(
        _wrapLoaded(profile: _profile, subscribeBloc: subBloc),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text("S'abonner"), findsOneWidget);
      final calls = loadCalls(subBloc);
      expect(calls, hasLength(1));
      expect(calls.single.travelerId, _userId);
    },
  );

  testWidgets('mon profil (id égal à mon id) → ni bouton ni chargement', (
    tester,
  ) async {
    final subBloc = readySubBloc();

    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        subscribeBloc: subBloc,
        authUserId: _userId, // same → own profile
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text("S'abonner"), findsNothing);
    expect(find.text('Abonné ✓'), findsNothing);
    verifyNever(() => subBloc.add(any()));
  });

  testWidgets('mon profil (userId null) → ni bouton ni chargement', (
    tester,
  ) async {
    final subBloc = readySubBloc();

    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        subscribeBloc: subBloc,
        screenUserId: null,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text("S'abonner"), findsNothing);
    verifyNever(() => subBloc.add(any()));
  });

  testWidgets(
    'utilisateur courant inconnu : statut chargé une fois le profil reçu',
    (tester) async {
      final subBloc = readySubBloc();
      final authBloc = MockAuthBloc();
      when(() => authBloc.state).thenReturn(const AuthInitial());
      when(
        () => authBloc.stream,
      ).thenAnswer((_) => Stream.value(const AuthInitial()));

      final profileBloc = MockProfilePublicBloc();
      final loaded = ProfilePublicLoaded(
        profile: _profile,
        recentRatings: _ratingSummary,
      );
      whenListen(
        profileBloc,
        Stream.fromIterable([loaded]),
        initialState: const ProfilePublicLoading(),
      );

      await tester.pumpWidget(
        _wrap(profileBloc, subscribeBloc: subBloc, authBloc: authBloc),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text("S'abonner"), findsOneWidget);
      final calls = loadCalls(subBloc);
      expect(calls, hasLength(1));
      expect(calls.single.travelerId, _userId);
    },
  );

  testWidgets(
    'utilisateur courant inconnu, profil en chargement : rien avant le profil',
    (tester) async {
      final subBloc = readySubBloc();
      final authBloc = MockAuthBloc();
      when(() => authBloc.state).thenReturn(const AuthInitial());
      when(
        () => authBloc.stream,
      ).thenAnswer((_) => Stream.value(const AuthInitial()));

      final profileBloc = MockProfilePublicBloc();
      when(() => profileBloc.state).thenReturn(const ProfilePublicLoading());
      when(() => profileBloc.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(
        _wrap(profileBloc, subscribeBloc: subBloc, authBloc: authBloc),
      );
      await tester.pump(const Duration(milliseconds: 600));

      verifyNever(() => subBloc.add(any()));
    },
  );

  testWidgets('le statut n\'est chargé qu\'une fois (init puis profil reçu)', (
    tester,
  ) async {
    final subBloc = readySubBloc();
    final profileBloc = MockProfilePublicBloc();
    final loaded = ProfilePublicLoaded(
      profile: _profile,
      recentRatings: _ratingSummary,
    );
    whenListen(
      profileBloc,
      Stream.fromIterable([loaded]),
      initialState: const ProfilePublicLoading(),
    );

    await tester.pumpWidget(_wrap(profileBloc, subscribeBloc: subBloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(loadCalls(subBloc), hasLength(1));
  });

  testWidgets('shows "Abonné ✓" + bell icon when already subscribed', (
    tester,
  ) async {
    final subBloc = MockTravelerSubscribeBloc();
    const subState = TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: true,
      pushEnabled: true,
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

    await tester.pumpWidget(
      _wrapLoaded(profile: _profile, subscribeBloc: subBloc),
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
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

    await tester.pumpWidget(
      _wrapLoaded(profile: _profile, subscribeBloc: subBloc),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text("S'abonner"));
    verify(() => subBloc.add(const SubscribePressed())).called(1);
  });

  testWidgets('tapping bell dispatches TogglePushPressed(!pushEnabled)', (
    tester,
  ) async {
    final subBloc = MockTravelerSubscribeBloc();
    const subState = TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: true,
      pushEnabled: true,
    );
    when(() => subBloc.state).thenReturn(subState);
    when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

    await tester.pumpWidget(
      _wrapLoaded(profile: _profile, subscribeBloc: subBloc),
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

  testWidgets(
    'tapping "Abonné ✓" opens confirm dialog, confirming unsubscribes',
    (tester) async {
      final subBloc = MockTravelerSubscribeBloc();
      const subState = TravelerSubscribeState(
        status: TravelerSubscribeStatus.ready,
        subscribed: true,
      );
      when(() => subBloc.state).thenReturn(subState);
      when(() => subBloc.stream).thenAnswer((_) => Stream.value(subState));

      await tester.pumpWidget(
        _wrapLoaded(profile: _profile, subscribeBloc: subBloc),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('Abonné ✓'));
      await tester.pumpAndSettle();

      expect(find.text('Se désabonner ?'), findsOneWidget);

      await tester.tap(find.text('Se désabonner'));
      await tester.pumpAndSettle();

      verify(() => subBloc.add(const UnsubscribePressed())).called(1);
    },
  );

  // ── 10. Menu ⋯ : Signaler + Bloquer ───────────────────────────────────────

  testWidgets('menu ⋯ absent when viewing own profile', (tester) async {
    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        authUserId: _userId, // own profile
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byTooltip("Plus d'options"), findsNothing);
  });

  testWidgets(
    'menu ⋯ présent, « Signaler » navigue vers report-incident avec la cible user',
    (tester) async {
      await tester.pumpWidget(_wrapLoaded(profile: _profile));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byTooltip("Plus d'options"), findsOneWidget);

      await tester.tap(find.byTooltip("Plus d'options"));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Signaler Fatou Diallo'));
      await tester.pumpAndSettle();

      expect(find.text('Reported: user-1'), findsOneWidget);
    },
  );

  testWidgets(
    'Signaler et Bloquer sont regroupés dans le même menu ⋯, pas deux icônes',
    (tester) async {
      await tester.pumpWidget(_wrapLoaded(profile: _profile));
      await tester.pump(const Duration(milliseconds: 600));

      // Une seule affordance dans l'app bar, aucune icône « Signaler » isolée.
      expect(find.byTooltip('Signaler'), findsNothing);

      await tester.tap(find.byTooltip("Plus d'options"));
      await tester.pumpAndSettle();

      expect(find.text('Signaler Fatou Diallo'), findsOneWidget);
      expect(find.text('Bloquer Fatou Diallo'), findsOneWidget);
    },
  );

  testWidgets('« Bloquer » est absent du menu ⋯ sur son propre profil', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapLoaded(
        profile: _profile,
        authUserId: _userId, // own profile
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byTooltip("Plus d'options"), findsNothing);
    expect(find.text('Bloquer Fatou Diallo'), findsNothing);
  });

  testWidgets(
    'profil pas encore chargé : « Signaler » reste, « Bloquer » attend le nom',
    (tester) async {
      // Sans displayName, « Bloquer X » n'a pas de sujet à nommer : on
      // n'affiche pas une action destructive anonyme.
      when(() => bloc.state).thenReturn(const ProfilePublicLoading());

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.byTooltip("Plus d'options"));
      // Pas de pumpAndSettle ici : le squelette de chargement fait tourner un
      // shimmer en boucle, l'arbre ne se stabilise jamais.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Signaler'), findsOneWidget);
      expect(find.textContaining('Bloquer'), findsNothing);
    },
  );

  // ── 11. Coverage — avatar network image + contact/availability section ──────

  testWidgets(
    'shows hero avatar, review avatar and disponibilité section when data present',
    (tester) async {
      const profileWithAvatarAndContact = ProfilePublicModel(
        userId: _userId,
        displayName: 'Fatou Diallo',
        avatarUrl: 'https://example.com/avatar.jpg',
        kycVerified: true,
        isProAccount: false,
        isKiloPro: false,
        completedBidsCount: 12,
        averageRating: 4.8,
        ratingCount: 7,
        memberSince: 'mars 2025',
        badges: [],
        contactMode: 'both',
        responseDelayHours: 5,
      );
      final summaryWithAuthorAvatar = RatingSummary(
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
            authorAvatarUrl: 'https://example.com/author.jpg',
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
          ),
        ],
        page: 0,
        totalPages: 1,
      );
      final b = MockProfilePublicBloc();
      final loadedState = ProfilePublicLoaded(
        profile: profileWithAvatarAndContact,
        recentRatings: summaryWithAuthorAvatar,
      );
      when(() => b.state).thenReturn(loadedState);
      when(() => b.stream).thenAnswer((_) => Stream.value(loadedState));

      await tester.pumpWidget(_wrap(b));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(Image), findsWidgets);
      expect(find.text('DISPONIBILITÉ', skipOffstage: false), findsOneWidget);
      expect(find.text('Appel & message', skipOffstage: false), findsOneWidget);
      expect(find.text('Répond en < 5h', skipOffstage: false), findsOneWidget);
    },
  );

  testWidgets('disponibilité section shows call-only and message-only labels', (
    tester,
  ) async {
    for (final entry in {
      'call': 'Joignable par appel',
      'message': 'Joignable par message',
    }.entries) {
      final profile = ProfilePublicModel(
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
        contactMode: entry.key,
      );
      final b = MockProfilePublicBloc();
      final loadedState = ProfilePublicLoaded(
        profile: profile,
        recentRatings: _ratingSummary,
      );
      when(() => b.state).thenReturn(loadedState);
      when(() => b.stream).thenAnswer((_) => Stream.value(loadedState));

      await tester.pumpWidget(_wrap(b));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text(entry.value, skipOffstage: false), findsOneWidget);
    }
  });

  // ── 12. Ligne méta (rating/avis/memberSince) ──────────────────────────────

  testWidgets('ligne méta : singulier "1 avis" en français', (tester) async {
    await tester.pumpWidget(_wrapLoaded(profile: _profileOneReview));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.textContaining('4,5 · 1 avis · mars 2025', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('ligne méta : "12 avis" en français (pas de forme spéciale)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapLoaded(profile: _profileTwelveReviews));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.textContaining('4,5 · 12 avis · mars 2025', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets(
    'anglais : ligne méta, pastilles PRO/vérifié et statistiques traduites',
    (tester) async {
      useEnglish();
      const profile = ProfilePublicModel(
        userId: _userId,
        displayName: 'Fatou Diallo',
        kycVerified: true,
        isProAccount: true,
        isKiloPro: false,
        completedBidsCount: 3,
        averageRating: 4.5,
        ratingCount: 1,
        memberSince: 'mars 2025',
        badges: [],
      );

      await tester.pumpWidget(_wrapLoaded(profile: profile));
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.textContaining('4.5 · 1 review · mars 2025', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('✓ Verified', skipOffstage: false), findsOneWidget);
      expect(find.text('Pro', skipOffstage: false), findsOneWidget);
      expect(find.text('Rating', skipOffstage: false), findsOneWidget);
      expect(find.text('Deliveries', skipOffstage: false), findsOneWidget);
    },
  );

  testWidgets('anglais : douze avis traduits en "12 reviews"', (tester) async {
    useEnglish();

    await tester.pumpWidget(_wrapLoaded(profile: _profileTwelveReviews));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.textContaining('4.5 · 12 reviews · mars 2025', skipOffstage: false),
      findsOneWidget,
    );
  });

  // ── 13. Non-régression date d'avis (remplacement dd/MM/yyyy -> yMd) ──────

  testWidgets(
    'date d\'avis au format français (non-régression, DateTime(2026, 10, 6, 14, 5))',
    (tester) async {
      final summaryWithFixedDate = RatingSummary(
        averageRating: 4.5,
        ratingCount: 1,
        distribution: const {1: 0, 2: 0, 3: 0, 4: 0, 5: 1},
        ratings: [
          RatingItem(
            stars: 5,
            createdAt: DateTime(2026, 10, 6, 14, 5),
            excluded: false,
            authorName: 'Fixed Date',
          ),
        ],
        page: 0,
        totalPages: 1,
      );
      final b = MockProfilePublicBloc();
      final loadedState = ProfilePublicLoaded(
        profile: _profile,
        recentRatings: summaryWithFixedDate,
      );
      when(() => b.state).thenReturn(loadedState);
      when(() => b.stream).thenAnswer((_) => Stream.value(loadedState));

      await tester.pumpWidget(_wrap(b));
      await tester.pump(const Duration(milliseconds: 600));

      // Ancien motif 'dd/MM/yyyy' : rendu identique après passage à
      // DateFormat.yMd(locale).
      expect(find.text('06/10/2026', skipOffstage: false), findsOneWidget);
    },
  );

  testWidgets('date d\'avis au format anglais (DateTime(2026, 10, 6, 14, 5))', (
    tester,
  ) async {
    useEnglish();
    final summaryWithFixedDate = RatingSummary(
      averageRating: 4.5,
      ratingCount: 1,
      distribution: const {1: 0, 2: 0, 3: 0, 4: 0, 5: 1},
      ratings: [
        RatingItem(
          stars: 5,
          createdAt: DateTime(2026, 10, 6, 14, 5),
          excluded: false,
          authorName: 'Fixed Date',
        ),
      ],
      page: 0,
      totalPages: 1,
    );
    final b = MockProfilePublicBloc();
    final loadedState = ProfilePublicLoaded(
      profile: _profile,
      recentRatings: summaryWithFixedDate,
    );
    when(() => b.state).thenReturn(loadedState);
    when(() => b.stream).thenAnswer((_) => Stream.value(loadedState));

    await tester.pumpWidget(_wrap(b));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('10/6/2026', skipOffstage: false), findsOneWidget);
  });
}
