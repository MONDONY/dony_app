// Regression test for: selecting a capacity chip always results in availableKg = 15
// in the published announcement.
//
// Root cause: CapacityControl dispatches CapacityUnitChanged to AnnouncementFormBloc,
// which updates state.availableKg. But _submit() reads _availableKgNotifier.value
// (a local ValueNotifier), which was never synced back from the bloc.
//
// Fix: a BlocListener in build() syncs state.availableKg → _availableKgNotifier
// whenever the bloc emits a new availableKg value.
//
// Test strategy: edit mode with a pre-filled announcement (availableKg = 10),
// tap "1 valise 32 kg" chip at step 1, navigate to step 2, tap "Enregistrer",
// and verify AnnouncementUpdateRequested.availableKg == 32 (not 10 or 15).

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/address_suggestion.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAnnouncementBloc extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class MockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

class MockCitySearchBloc extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

class MockAddressAutocompleteService extends Mock
    implements AddressAutocompleteService {}

class MockCityRepository extends Mock implements CityRepository {}

class MockPriceGridRepository extends Mock implements PriceGridRepository {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _stripeUser = UserModel(
  id: 'u1',
  roles: const [],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  stripeAccountStatus: 'ONBOARDING_COMPLETE',
);

/// Announcement with all required fields and availableKg = 10.
/// When the user taps "1 valise 32 kg", _submit() must dispatch availableKg = 32.
final _testAnnouncement = AnnouncementModel(
  id: 'ann-cap-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2027, 8, 15),
  availableKg: 10,
  totalKg: 10,
  pricePerKg: 6,
  status: 'ACTIVE',
  transportMode: TransportMode.plane,
  pickupAddress: AddressData(label: '10 rue de Rivoli, Paris', lat: 48.86, lng: 2.35),
  deliveryAddress: AddressData(label: 'Aéroport CDG, Roissy', lat: 49.01, lng: 2.55),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  acceptedPaymentMethods: const {BidPaymentMethod.stripe},
);

// ── Builder ───────────────────────────────────────────────────────────────────

Widget _buildHost({
  required MockAnnouncementBloc announcementBloc,
  required MockCommissionMethodBloc commissionBloc,
  required MockAuthBloc authBloc,
  required MockStripeAccountBloc stripeBloc,
  AnnouncementModel? announcement,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open-sheet-btn'),
              onPressed: () {
                CreateAnnouncementBottomSheet.show(ctx, announcement: announcement);
              },
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/announcements',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Announcements'))),
      ),
      GoRoute(
        path: '/connect/onboarding/intro',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Stripe onboarding'))),
      ),
      GoRoute(
        path: '/payments/commission-method',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Commission'))),
      ),
      GoRoute(
        path: '/profile/upgrade-to-pro',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Upgrade'))),
      ),
    ],
  );
  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<StripeAccountBloc>.value(value: stripeBloc),
    ],
    child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
}

const _settle = Duration(milliseconds: 600);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockAnnouncementBloc announcementBloc;
  late MockCommissionMethodBloc commissionBloc;
  late MockAuthBloc authBloc;
  late MockStripeAccountBloc stripeBloc;
  late MockCityRepository cityRepo;

  setUpAll(() async {
    await initializeDateFormatting('fr');

    registerFallbackValue(AnnouncementInitial());
    registerFallbackValue(CommissionMethodInitial());
    registerFallbackValue(const CitySearchInitial());
    registerFallbackValue(AnnouncementUpdateRequested(
      id: '',
      departureCity: '',
      arrivalCity: '',
      departureDate: DateTime(2026),
      pickupAddress: AddressData(label: '', lat: 0, lng: 0),
      deliveryAddress: AddressData(label: '', lat: 0, lng: 0),
      availableKg: 0,
      pricePerKg: 0,
      transportMode: TransportMode.plane,
    ));
    registerFallbackValue(AnnouncementCreateRequested(
      departureCity: '',
      arrivalCity: '',
      departureDate: DateTime(2026),
      pickupAddress: AddressData(label: '', lat: 0, lng: 0),
      deliveryAddress: AddressData(label: '', lat: 0, lng: 0),
      availableKg: 0,
      pricePerKg: 0,
      transportMode: TransportMode.plane,
    ));

    cityRepo = MockCityRepository();
    when(() => cityRepo.searchCities(any())).thenAnswer((_) async => []);
    when(() => cityRepo.getPopularCorridors()).thenAnswer((_) async => []);

    if (!getIt.isRegistered<CitySearchBloc>()) {
      getIt.registerFactory<CitySearchBloc>(() => CitySearchBloc(cityRepo));
    }
  });

  tearDownAll(() {
    if (getIt.isRegistered<AddressAutocompleteService>()) {
      getIt.unregister<AddressAutocompleteService>();
    }
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<CommissionMethodBloc>()) {
      getIt.unregister<CommissionMethodBloc>();
    }
    if (getIt.isRegistered<PriceGridRepository>()) {
      getIt.unregister<PriceGridRepository>();
    }
  });

  setUp(() {
    announcementBloc = MockAnnouncementBloc();
    when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
    when(() => announcementBloc.stream)
        .thenAnswer((_) => const Stream.empty());
    when(() => announcementBloc.add(any())).thenReturn(null);

    commissionBloc = MockCommissionMethodBloc();
    when(() => commissionBloc.state).thenReturn(CommissionMethodNotConfigured());
    when(() => commissionBloc.stream)
        .thenAnswer((_) => const Stream.empty());

    authBloc = MockAuthBloc();
    when(() => authBloc.state).thenReturn(AuthAuthenticated(_stripeUser));
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());

    stripeBloc = MockStripeAccountBloc();
    when(() => stripeBloc.state).thenReturn(StripeAccountReady(
      const ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
    ));
    when(() => stripeBloc.stream).thenAnswer((_) => const Stream.empty());

    final autocomplete = MockAddressAutocompleteService();
    when(() => autocomplete.search(any(), any()))
        .thenAnswer((_) async => const <AddressSuggestion>[]);

    if (getIt.isRegistered<AddressAutocompleteService>()) {
      getIt.unregister<AddressAutocompleteService>();
    }
    getIt.registerSingleton<AddressAutocompleteService>(autocomplete);

    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    getIt.registerFactory<AnnouncementBloc>(() => announcementBloc);

    if (getIt.isRegistered<CommissionMethodBloc>()) {
      getIt.unregister<CommissionMethodBloc>();
    }
    getIt.registerFactory<CommissionMethodBloc>(() => commissionBloc);

    if (getIt.isRegistered<PriceGridRepository>()) {
      getIt.unregister<PriceGridRepository>();
    }
    getIt.registerLazySingleton<PriceGridRepository>(
      () => MockPriceGridRepository(),
    );
  });

  tearDown(() {
    announcementBloc.close();
    commissionBloc.close();
    authBloc.close();
    stripeBloc.close();
    if (getIt.isRegistered<AddressAutocompleteService>()) {
      getIt.unregister<AddressAutocompleteService>();
    }
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<CommissionMethodBloc>()) {
      getIt.unregister<CommissionMethodBloc>();
    }
    if (getIt.isRegistered<PriceGridRepository>()) {
      getIt.unregister<PriceGridRepository>();
    }
  });

  // ── Regression test ───────────────────────────────────────────────────────
  // FAIL before fix: submit dispatches availableKg == 10 (stale notifier value)
  // PASS after fix:  submit dispatches availableKg == 32 (synced from BLoC)

  testWidgets(
    'capacityChipSync: selecting "1 valise 32 kg" chip results in '
    'AnnouncementUpdateRequested with availableKg == 32 (not stale 10)',
    (tester) async {
      // Very tall viewport so all steps fit on screen
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildHost(
        announcementBloc: announcementBloc,
        commissionBloc: commissionBloc,
        authBloc: authBloc,
        stripeBloc: stripeBloc,
        announcement: _testAnnouncement,
      ));
      await tester.pump(_settle);

      // Open the bottom sheet in edit mode
      await tester.tap(find.byKey(const Key('open-sheet-btn')));
      await tester.pump(_settle);
      await tester.pump(_settle);

      // We are at step 0 (Trajet). Navigate to step 1 (Lieux & capacité).
      await tester.tap(find.text('Continuer'));
      await tester.pump(_settle);

      // At step 1, CapacityControl is visible.
      // Tap the "1 valise 32 kg" chip to dispatch CapacityUnitChanged(suitcase32kg).
      // This updates AnnouncementFormBloc.state.availableKg → 32.
      // Without fix: _availableKgNotifier stays at 10 (stale).
      // With fix: BlocListener syncs _availableKgNotifier → 32.
      expect(find.text('1 valise 32 kg'), findsOneWidget,
          reason: 'CapacityControl must show "1 valise 32 kg" chip at step 1');
      await tester.tap(find.text('1 valise 32 kg'));
      await tester.pump(_settle);

      // Navigate to step 2 (Prix & conditions)
      await tester.tap(find.text('Continuer'));
      await tester.pump(_settle);

      // At step 2 in edit mode, the submit button is "Enregistrer"
      final submitBtn = find.byKey(const Key('create-announcement-submit'));
      expect(submitBtn, findsOneWidget,
          reason: '"Enregistrer" button must be visible at step 2 in edit mode');

      // Tap submit
      await tester.tap(submitBtn);
      await tester.pump();

      // Verify that AnnouncementUpdateRequested was dispatched with availableKg == 32.
      // Before the fix: availableKg == 10 (stale _availableKgNotifier value).
      // After  the fix: availableKg == 32 (synced from BLoC).
      verify(
        () => announcementBloc.add(
          any(
            that: predicate<AnnouncementEvent>(
              (e) =>
                  e is AnnouncementUpdateRequested &&
                  e.availableKg == 32.0,
              'AnnouncementUpdateRequested with availableKg == 32.0',
            ),
          ),
        ),
      ).called(1);
    },
  );
}
