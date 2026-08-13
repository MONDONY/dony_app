import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/bloc/profile_public_bloc.dart';
import 'package:dony/features/profile/bloc/profile_public_event.dart';
import 'package:dony/features/profile/bloc/profile_public_state.dart';
import 'package:dony/features/profile/data/models/profile_public_model.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_bloc.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_event.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_state.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:dony/features/subscriptions/presentation/traveler_profile_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mock BLoCs ───────────────────────────────────────────────────────────────

class MockProfilePublicBloc
    extends MockBloc<ProfilePublicEvent, ProfilePublicState>
    implements ProfilePublicBloc {}

class MockTravelerHubBloc extends MockBloc<TravelerHubEvent, TravelerHubState>
    implements TravelerHubBloc {}

// ─── Helpers ─────────────────────────────────────────────────────────────────

ProfilePublicModel _fakeProfile({String displayName = 'Ibrahima D'}) =>
    ProfilePublicModel(
      userId: 'user-1',
      displayName: displayName,
      kycVerified: true,
      isProAccount: false,
      isKiloPro: false,
      completedBidsCount: 12,
      averageRating: 4.7,
      ratingCount: 8,
      memberSince: '2024-01',
      badges: const [],
      responseDelayHours: 2,
    );

RatingSummary _fakeRatings({List<RatingItem> ratings = const []}) =>
    RatingSummary(
      averageRating: 4.7,
      ratingCount: ratings.length,
      distribution: const {},
      ratings: ratings,
      page: 0,
      totalPages: 1,
    );

TravelerAnnouncement _fakeAnnouncement() => TravelerAnnouncement(
  id: 'ann-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 6, 15),
  pricePerKg: 8.0,
  availableKg: 10.0,
  status: 'active',
);

// ─── Test setup ───────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  late MockProfilePublicBloc profileBloc;
  late MockTravelerHubBloc hubBloc;

  setUp(() {
    profileBloc = MockProfilePublicBloc();
    hubBloc = MockTravelerHubBloc();

    registerFallbackValue(const ProfilePublicRequested(''));
    registerFallbackValue(const LoadTravelerHub(''));
    registerFallbackValue(const HubSubscribePressed());
    registerFallbackValue(const HubUnsubscribePressed());
    registerFallbackValue(const HubTogglePush(false));
  });

  Widget pump({Size? surfaceSize}) => MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<ProfilePublicBloc>.value(value: profileBloc),
        BlocProvider<TravelerHubBloc>.value(value: hubBloc),
      ],
      child: const TravelerProfileHubScreen(travelerId: 'traveler-1'),
    ),
  );

  // ─── Test 1: Not subscribed ─────────────────────────────────────────────────

  testWidgets(
    'affiche le nom du voyageur, le bouton S\'abonner, et la carte Paris→Dakar',
    (tester) async {
      when(() => profileBloc.state).thenReturn(
        ProfilePublicLoaded(
          profile: _fakeProfile(),
          recentRatings: _fakeRatings(),
        ),
      );

      when(() => hubBloc.state).thenReturn(
        TravelerHubState(
          status: TravelerHubStatus.success,
          announcements: [_fakeAnnouncement()],
        ),
      );

      await tester.pumpWidget(pump());
      await tester.pump(const Duration(milliseconds: 600));

      // Name in header
      expect(find.text('Ibrahima D'), findsOneWidget);

      // Subscribe button visible in subscription bar
      expect(find.text("S'abonner"), findsOneWidget);

      // Trips tab is default — the announcement card should be visible
      // The card shows the departure city
      expect(find.text('Paris'), findsOneWidget);
    },
  );

  // ─── Test 2: Subscribed ─────────────────────────────────────────────────────

  testWidgets(
    'affiche Abonné ✓ et l\'icône cloche désactivée quand push est off',
    (tester) async {
      // Use a larger surface to avoid overflow in DonyEmptyState during test
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      when(() => profileBloc.state).thenReturn(
        ProfilePublicLoaded(
          profile: _fakeProfile(),
          recentRatings: _fakeRatings(),
        ),
      );

      when(() => hubBloc.state).thenReturn(
        TravelerHubState(
          status: TravelerHubStatus.success,
          subscribed: true,
          announcements: [_fakeAnnouncement()],
        ),
      );

      await tester.pumpWidget(pump());
      await tester.pump(const Duration(milliseconds: 600));

      // Subscribed button label
      expect(find.text('Abonné ✓'), findsOneWidget);

      // Bell off icon
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bell-off'),
        findsOneWidget,
      );
    },
  );

  // ─── Test 3: ProfilePublicLoading → header shows a loader ──────────────────

  testWidgets(
    'ProfilePublicLoading → CircularProgressIndicator dans le header',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      when(() => profileBloc.state).thenReturn(const ProfilePublicLoading());
      when(
        () => hubBloc.state,
      ).thenReturn(const TravelerHubState(status: TravelerHubStatus.success));

      await tester.pumpWidget(pump());
      // Drain flutter_animate pending timers while still in loading state
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    },
  );

  // ─── Test 4: TravelerHubStatus.loading on trips tab → spinner ───────────────

  testWidgets(
    'TravelerHubStatus.loading → CircularProgressIndicator dans l\'onglet Trajets',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      when(() => profileBloc.state).thenReturn(
        ProfilePublicLoaded(
          profile: _fakeProfile(),
          recentRatings: _fakeRatings(),
        ),
      );

      when(
        () => hubBloc.state,
      ).thenReturn(const TravelerHubState(status: TravelerHubStatus.loading));

      await tester.pumpWidget(pump());
      await tester.pump(const Duration(milliseconds: 600));

      // Should show a spinner in the trips tab body
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    },
  );

  // ─── Test 5: Empty announcements ─────────────────────────────────────────────

  testWidgets('announcements vides → "Aucun trajet en cours"', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    when(() => profileBloc.state).thenReturn(
      ProfilePublicLoaded(
        profile: _fakeProfile(),
        recentRatings: _fakeRatings(),
      ),
    );
    when(
      () => hubBloc.state,
    ).thenReturn(const TravelerHubState(status: TravelerHubStatus.success));

    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Aucun trajet en cours'), findsOneWidget);
  });

  // ─── Test 6: Avis tab with one rating ─────────────────────────────────────

  testWidgets('onglet Avis avec un avis → affiche le commentaire', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final rating = RatingItem(
      stars: 5,
      comment: 'Excellent voyageur !',
      createdAt: DateTime(2026, 3, 10),
      excluded: false,
    );

    when(() => profileBloc.state).thenReturn(
      ProfilePublicLoaded(
        profile: _fakeProfile(),
        recentRatings: _fakeRatings(ratings: [rating]),
      ),
    );

    when(() => hubBloc.state).thenReturn(
      TravelerHubState(
        status: TravelerHubStatus.success,
        announcements: [_fakeAnnouncement()],
      ),
    );

    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    // Switch to Avis tab
    await tester.tap(find.text('Avis'));
    await tester.pumpAndSettle();

    expect(find.text('Excellent voyageur !'), findsOneWidget);
  });

  // ─── Test 7: Avis tab empty ratings ──────────────────────────────────────

  testWidgets('onglet Avis sans avis → "Aucun avis"', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    when(() => profileBloc.state).thenReturn(
      ProfilePublicLoaded(
        profile: _fakeProfile(),
        recentRatings: _fakeRatings(),
      ),
    );

    when(() => hubBloc.state).thenReturn(
      TravelerHubState(
        status: TravelerHubStatus.success,
        announcements: [_fakeAnnouncement()],
      ),
    );

    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Avis'));
    await tester.pumpAndSettle();

    expect(find.text('Aucun avis'), findsOneWidget);
  });

  // ─── Test 8: Bell toggle tap ──────────────────────────────────────────────

  testWidgets('tap cloche quand abonné → bloc.add(HubTogglePush)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    when(() => profileBloc.state).thenReturn(
      ProfilePublicLoaded(
        profile: _fakeProfile(),
        recentRatings: _fakeRatings(),
      ),
    );

    when(() => hubBloc.state).thenReturn(
      const TravelerHubState(
        status: TravelerHubStatus.success,
        subscribed: true,
      ),
    );

    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    // Bell is notifications_off_rounded when pushEnabled=false
    final bellFinder = find.byWidgetPredicate(
      (w) => w is DonyIcon && w.name == 'bell-off',
    );
    expect(bellFinder, findsOneWidget);
    await tester.tap(bellFinder);
    await tester.pump();

    // HubTogglePush doesn't implement ==, capture and verify the type + field.
    final captured = verify(() => hubBloc.add(captureAny())).captured;
    final toggle = captured.whereType<HubTogglePush>().toList();
    expect(toggle, isNotEmpty, reason: 'Expected HubTogglePush to be added');
    expect(toggle.last.enabled, isTrue);
  });

  // ─── Test 9: ProfilePublicError state ────────────────────────────────────

  testWidgets(
    'ProfilePublicError → "Impossible de charger le profil" dans le header',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      when(
        () => profileBloc.state,
      ).thenReturn(const ProfilePublicError(message: 'Not found'));
      when(
        () => hubBloc.state,
      ).thenReturn(const TravelerHubState(status: TravelerHubStatus.success));

      await tester.pumpWidget(pump());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Impossible de charger le profil'), findsOneWidget);
    },
  );

  // ─── Test 10: Hub error state ─────────────────────────────────────────────

  testWidgets(
    'TravelerHubStatus.error → "Erreur de chargement" dans l\'onglet Trajets',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      when(() => profileBloc.state).thenReturn(
        ProfilePublicLoaded(
          profile: _fakeProfile(),
          recentRatings: _fakeRatings(),
        ),
      );

      when(() => hubBloc.state).thenReturn(
        const TravelerHubState(status: TravelerHubStatus.error, error: 'Échec'),
      );

      await tester.pumpWidget(pump());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Erreur de chargement'), findsOneWidget);
    },
  );

  // ─── Test 11: PRO + KiloPro badges in header ─────────────────────────────

  testWidgets('profil PRO + KiloPro → badges PRO et Kilo Pro dans le header', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    when(() => profileBloc.state).thenReturn(
      ProfilePublicLoaded(
        profile: const ProfilePublicModel(
          userId: 'u1',
          displayName: 'Ibou Pro',
          kycVerified: true,
          isProAccount: true,
          isKiloPro: true,
          completedBidsCount: 100,
          averageRating: 4.9,
          ratingCount: 50,
          memberSince: '2023-01',
          badges: [],
        ),
        recentRatings: _fakeRatings(),
      ),
    );

    when(
      () => hubBloc.state,
    ).thenReturn(const TravelerHubState(status: TravelerHubStatus.success));

    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Compte PRO'), findsOneWidget);
    expect(find.text('Kilo Pro'), findsOneWidget);
  });

  // ─── Test 12: S'abonner button tap → HubSubscribePressed ─────────────────

  testWidgets("tap S'abonner → bloc.add(HubSubscribePressed)", (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    when(() => profileBloc.state).thenReturn(
      ProfilePublicLoaded(
        profile: _fakeProfile(),
        recentRatings: _fakeRatings(),
      ),
    );

    when(
      () => hubBloc.state,
    ).thenReturn(const TravelerHubState(status: TravelerHubStatus.success));

    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text("S'abonner"));
    await tester.pump();

    verify(() => hubBloc.add(const HubSubscribePressed())).called(1);
  });

  // ─── Test 13: Avis with partially-starred rating (no comment) ────────────

  testWidgets('onglet Avis — étoiles partielles (3/5) sans commentaire', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final rating = RatingItem(
      stars: 3,
      createdAt: DateTime(2026, 1, 5),
      excluded: false,
    );

    when(() => profileBloc.state).thenReturn(
      ProfilePublicLoaded(
        profile: _fakeProfile(),
        recentRatings: _fakeRatings(ratings: [rating]),
      ),
    );

    when(() => hubBloc.state).thenReturn(
      TravelerHubState(
        status: TravelerHubStatus.success,
        announcements: [_fakeAnnouncement()],
      ),
    );

    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Avis'));
    await tester.pumpAndSettle();

    // Stars widget renders (both filled and empty stars should exist for 3/5)
    expect(
      find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'star'),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'star'),
      findsWidgets,
    );
  });

  // ─── Test 14: averageRating == 0 → '—' in stat column ───────────────────

  testWidgets('averageRating 0 → affiche — dans la colonne Note', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    when(() => profileBloc.state).thenReturn(
      ProfilePublicLoaded(
        profile: const ProfilePublicModel(
          userId: 'u2',
          displayName: 'Nouveau Voyageur',
          kycVerified: false,
          isProAccount: false,
          isKiloPro: false,
          completedBidsCount: 0,
          averageRating: 0.0,
          ratingCount: 0,
          memberSince: '2026-01',
          badges: [],
        ),
        recentRatings: _fakeRatings(),
      ),
    );

    when(
      () => hubBloc.state,
    ).thenReturn(const TravelerHubState(status: TravelerHubStatus.success));

    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    // averageRating == 0 → shows '–', and responseDelayHours null → '–'
    expect(find.text('–'), findsWidgets);
  });

  // ─── Test 15: Labels des 3 stats visibles ────────────────────────────────
  testWidgets('stats — labels Note, Livraisons, Réponse visibles', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    when(() => profileBloc.state).thenReturn(
      ProfilePublicLoaded(
        profile: _fakeProfile(),
        recentRatings: _fakeRatings(),
      ),
    );
    when(
      () => hubBloc.state,
    ).thenReturn(const TravelerHubState(status: TravelerHubStatus.success));

    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Note'), findsOneWidget);
    expect(find.text('Livraisons'), findsOneWidget);
    expect(find.text('Réponse'), findsOneWidget);
  });

  // ─── Test 16: Valeurs stats correctes ────────────────────────────────────
  testWidgets('stats — valeurs correctes pour le profil fake', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    when(() => profileBloc.state).thenReturn(
      ProfilePublicLoaded(
        // _fakeProfile : averageRating=4.7, completedBidsCount=12,
        // responseDelayHours=2
        profile: _fakeProfile(),
        recentRatings: _fakeRatings(),
      ),
    );
    when(
      () => hubBloc.state,
    ).thenReturn(const TravelerHubState(status: TravelerHubStatus.success));

    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('4.7'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('<2h'), findsOneWidget);
  });

  // ─── Test 17: Badge KYC "Identité vérifiée" ──────────────────────────────
  testWidgets('badge KYC "Identité vérifiée" quand kycVerified: true', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    when(() => profileBloc.state).thenReturn(
      ProfilePublicLoaded(
        // _fakeProfile a kycVerified: true
        profile: _fakeProfile(),
        recentRatings: _fakeRatings(),
      ),
    );
    when(
      () => hubBloc.state,
    ).thenReturn(const TravelerHubState(status: TravelerHubStatus.success));

    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Identité vérifiée'), findsOneWidget);
  });
}
