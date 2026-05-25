import 'package:bloc_test/bloc_test.dart';
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

class MockTravelerHubBloc
    extends MockBloc<TravelerHubEvent, TravelerHubState>
    implements TravelerHubBloc {}

// ─── Helpers ─────────────────────────────────────────────────────────────────

ProfilePublicModel _fakeProfile({String displayName = 'Ibrahima D'}) =>
    ProfilePublicModel(
      userId: 'user-1',
      displayName: displayName,
      avatarUrl: null,
      kycVerified: true,
      isProAccount: false,
      isKiloPro: false,
      completedBidsCount: 12,
      averageRating: 4.7,
      ratingCount: 8,
      memberSince: '2024-01',
      badges: const [],
      contactMode: null,
      responseDelayHours: 2,
    );

RatingSummary _fakeRatings() => const RatingSummary(
      averageRating: 4.7,
      ratingCount: 0,
      distribution: {},
      ratings: [],
      page: 0,
      totalPages: 0,
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

  Widget pump() => MaterialApp(
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
        subscribed: false,
        pushEnabled: false,
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
  });

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
        pushEnabled: false,
        announcements: [_fakeAnnouncement()],
      ),
    );

    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    // Subscribed button label
    expect(find.text('Abonné ✓'), findsOneWidget);

    // Bell off icon
    expect(find.byIcon(Icons.notifications_off_rounded), findsOneWidget);
  });
}
