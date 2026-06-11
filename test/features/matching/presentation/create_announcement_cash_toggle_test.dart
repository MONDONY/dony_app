import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/screens/create_announcement_screen.dart';
import 'package:dony/features/matching/presentation/widgets/cash_commission_notice.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class MockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

class MockCitySearchBloc extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

class MockTripTemplateBloc
    extends MockBloc<TripTemplateEvent, TripTemplateState>
    implements TripTemplateBloc {}

/// Mock avec une liste de modèles vide → la barre de suggestions se réduit à
/// SizedBox.shrink(), comme en l'absence de modèles enregistrés.
MockTripTemplateBloc _stubTemplateBloc() {
  final bloc = MockTripTemplateBloc();
  when(() => bloc.state).thenReturn(const TripTemplateState());
  when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  return bloc;
}

class MockAddressAutocompleteService extends Mock
    implements AddressAutocompleteService {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _validCard = CommissionMethod(
  brand: 'visa',
  last4: '4242',
  expMonth: 12,
  expYear: 2028,
  expirationStatus: ExpirationStatus.valid,
);

final _testAnnouncementWithCash = AnnouncementModel(
  id: 'ann-cash-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 8, 15),
  availableKg: 10,
  totalKg: 10,
  pricePerKg: 7,
  status: 'ACTIVE',
  transportMode: TransportMode.plane,
  pickupAddress: AddressData(label: '10 rue de Rivoli', lat: 48.86, lng: 2.35),
  deliveryAddress: AddressData(label: 'CDG', lat: 49.01, lng: 2.55),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  acceptedPaymentMethods: const {BidPaymentMethod.stripe, BidPaymentMethod.cash},
);

// ── Builder ───────────────────────────────────────────────────────────────────

Widget _buildScreen({
  required MockAnnouncementBloc announcementBloc,
  required MockCommissionMethodBloc commissionBloc,
  AnnouncementModel? announcement,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => MultiBlocProvider(
          providers: [
            BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
            BlocProvider<CommissionMethodBloc>.value(value: commissionBloc),
            BlocProvider<TripTemplateBloc>(create: (_) => _stubTemplateBloc()),
          ],
          child: CreateAnnouncementScreen(announcement: announcement),
        ),
      ),
      GoRoute(
        path: '/payments/commission-method',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('Commission method screen')),
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light);
}

// Pumps screen with a very tall viewport so all sections are visible without
// needing to scroll — this avoids scrollUntilVisible "too many elements" issues
// with GoRouter double-rendering.
const _kSettle = Duration(milliseconds: 600);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required MockAnnouncementBloc announcementBloc,
  required MockCommissionMethodBloc commissionBloc,
  AnnouncementModel? announcement,
}) async {
  // Very tall viewport: ensures all form sections fit on screen simultaneously.
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_buildScreen(
    announcementBloc: announcementBloc,
    commissionBloc: commissionBloc,
    announcement: announcement,
  ));
  await tester.pump(_kSettle);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockAnnouncementBloc announcementBloc;
  late MockCommissionMethodBloc commissionBloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');

    // Register fallback values for mocktail
    registerFallbackValue(AnnouncementInitial());
    registerFallbackValue(CommissionMethodInitial());
    registerFallbackValue(const CitySearchInitial());
    registerFallbackValue(CommissionMethodLoadRequested());
    registerFallbackValue(AnnouncementCreateRequested(
      departureCity: '',
      arrivalCity: '',
      departureDate: DateTime(2026),
      pickupAddress: AddressData(label: '', lat: 0, lng: 0),
      deliveryAddress: AddressData(label: '', lat: 0, lng: 0),
      availableKg: 0,
      pricePerKg: 0,
      transportMode: TransportMode.plane,
      handoverWindowStart: DateTime(2026, 6, 14, 16),
      handoverWindowEnd: DateTime(2026, 6, 14, 18),
    ));
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
      handoverWindowStart: DateTime(2026, 6, 14, 16),
      handoverWindowEnd: DateTime(2026, 6, 14, 18),
    ));

    // Register GetIt dependencies required by the screen widgets
    // (AddressPickerField and CityAutocompleteField call getIt internally)
    if (!getIt.isRegistered<AddressAutocompleteService>()) {
      final mockAutocomplete = MockAddressAutocompleteService();
      when(() => mockAutocomplete.search(any(), any())).thenAnswer((_) async => []);
      getIt.registerSingleton<AddressAutocompleteService>(mockAutocomplete);
    }
    if (!getIt.isRegistered<CitySearchBloc>()) {
      getIt.registerFactory<CitySearchBloc>(() {
        final bloc = MockCitySearchBloc();
        when(() => bloc.state).thenReturn(const CitySearchInitial());
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
        return bloc;
      });
    }
    if (!getIt.isRegistered<CommissionMethodBloc>()) {
      // Provide a factory so the screen doesn't crash if it tries to resolve it
      // (not needed in tests since we pass via BlocProvider.value, but defensive)
      getIt.registerFactory<CommissionMethodBloc>(() {
        final bloc = MockCommissionMethodBloc();
        when(() => bloc.state).thenReturn(CommissionMethodNotConfigured());
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
        return bloc;
      });
    }
  });

  setUp(() {
    announcementBloc = MockAnnouncementBloc();
    when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
    when(() => announcementBloc.stream).thenAnswer((_) => const Stream.empty());

    commissionBloc = MockCommissionMethodBloc();
  });

  // ── 1. cashToggle_alwaysEnabled (carte de commission non requise) ──────────

  testWidgets(
    'cashToggle_alwaysEnabled: switch enabled even when commission method not configured',
    (tester) async {
      when(() => commissionBloc.state)
          .thenReturn(CommissionMethodNotConfigured());
      when(() => commissionBloc.stream).thenAnswer((_) => const Stream.empty());

      await _pumpScreen(
        tester,
        announcementBloc: announcementBloc,
        commissionBloc: commissionBloc,
      );

      expect(find.byKey(const Key('payment-method-cash')), findsOneWidget);

      final cashSwitch = find.byKey(const Key('payment-method-cash'));
      final switchWidget = tester.widget<Switch>(
        find.descendant(of: cashSwitch, matching: find.byType(Switch)).last,
      );
      // La carte n'est plus requise à la création : vérification reportée à l'acceptation.
      expect(switchWidget.onChanged, isNotNull,
          reason:
              'CASH switch must be enabled regardless of commission method state');
      // L'ancien lien "Ajouter une carte commission →" ne doit plus exister.
      expect(find.byKey(const Key('add-commission-card-link')), findsNothing);
    },
  );

  // ── 2. cashToggle_revealsNoticeWhenEnabled ────────────────────────────────

  testWidgets(
    'cashToggle_revealsNoticeWhenEnabled: info notice appears only when CASH is on',
    (tester) async {
      when(() => commissionBloc.state)
          .thenReturn(CommissionMethodNotConfigured());
      when(() => commissionBloc.stream).thenAnswer((_) => const Stream.empty());

      await _pumpScreen(
        tester,
        announcementBloc: announcementBloc,
        commissionBloc: commissionBloc,
      );

      // En création le toggle démarre OFF → l'encart est masqué.
      expect(find.byType(CashCommissionNotice), findsNothing);

      // Activer le toggle Espèces.
      await tester.tap(find.byKey(const Key('payment-method-cash')));
      await tester.pump(); // rebuild
      await tester.pump(const Duration(milliseconds: 300)); // AnimatedSize + fadeIn

      expect(find.byType(CashCommissionNotice), findsOneWidget,
          reason:
              'L\'encart commission Dony doit apparaître quand Espèces est activé');
    },
  );

  // ── 3. cashToggle_enabledWhenValid ───────────────────────────────────────

  testWidgets(
    'cashToggle_enabledWhenValid: switch enabled and toggleable when card valid',
    (tester) async {
      when(() => commissionBloc.state)
          .thenReturn(CommissionMethodLoaded(_validCard));
      when(() => commissionBloc.stream).thenAnswer((_) => const Stream.empty());

      await _pumpScreen(
        tester,
        announcementBloc: announcementBloc,
        commissionBloc: commissionBloc,
      );

      expect(find.byKey(const Key('payment-method-cash')), findsOneWidget);

      final cashSwitch = find.byKey(const Key('payment-method-cash'));

      final switchWidgetBefore = tester.widget<Switch>(
        find.descendant(of: cashSwitch, matching: find.byType(Switch)).last,
      );
      // Switch must be enabled
      expect(switchWidgetBefore.onChanged, isNotNull,
          reason: 'CASH switch must be enabled when card is valid');
      // Initially false
      expect(switchWidgetBefore.value, isFalse);

      // Tap to enable CASH
      await tester.tap(cashSwitch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // settle notice fadeIn

      final switchWidgetAfter = tester.widget<Switch>(
        find.descendant(of: cashSwitch, matching: find.byType(Switch)).last,
      );
      expect(switchWidgetAfter.value, isTrue,
          reason: 'CASH switch must toggle to true after tap');
    },
  );

  // ── 4. cashToggle_includesCashInSubmit ───────────────────────────────────

  testWidgets(
    'cashToggle_includesCashInSubmit: tapping submit dispatches AnnouncementUpdateRequested with CASH',
    (tester) async {
      when(() => commissionBloc.state)
          .thenReturn(CommissionMethodLoaded(_validCard));
      when(() => commissionBloc.stream).thenAnswer((_) => const Stream.empty());
      // Capture all add() calls on the announcement bloc
      when(() => announcementBloc.add(any())).thenReturn(null);

      // Use edit mode: _testAnnouncementWithCash already has CASH enabled,
      // all required fields set (cities, date, transport, addresses).
      await _pumpScreen(
        tester,
        announcementBloc: announcementBloc,
        commissionBloc: commissionBloc,
        announcement: _testAnnouncementWithCash,
      );

      // Verify CASH switch starts ON (pre-populated from the announcement)
      final cashSwitch = find.byKey(const Key('payment-method-cash'));
      expect(cashSwitch, findsOneWidget);
      final switchWidget = tester.widget<Switch>(
        find.descendant(of: cashSwitch, matching: find.byType(Switch)).last,
      );
      expect(switchWidget.value, isTrue,
          reason: 'CASH switch must start ON in edit mode with CASH announcement');

      // Tap the submit button
      final submitBtn = find.byKey(const Key('create-announcement-submit'));
      expect(submitBtn, findsOneWidget);
      await tester.tap(submitBtn);
      await tester.pump();

      // Verify AnnouncementUpdateRequested was dispatched with CASH
      verify(() => announcementBloc.add(any(
            that: predicate<AnnouncementEvent>(
              (e) =>
                  e is AnnouncementUpdateRequested &&
                  e.acceptedPaymentMethods.contains('CASH') &&
                  e.acceptedPaymentMethods.contains('STRIPE'),
              'AnnouncementUpdateRequested with CASH and STRIPE',
            ),
          ))).called(1);
    },
  );

  // ── 5. cashToggle_initFromEditMode ───────────────────────────────────────

  testWidgets(
    'cashToggle_initFromEditMode: toggle starts ON when announcement has CASH',
    (tester) async {
      when(() => commissionBloc.state)
          .thenReturn(CommissionMethodLoaded(_validCard));
      when(() => commissionBloc.stream).thenAnswer((_) => const Stream.empty());

      await _pumpScreen(
        tester,
        announcementBloc: announcementBloc,
        commissionBloc: commissionBloc,
        announcement: _testAnnouncementWithCash,
      );

      expect(find.byKey(const Key('payment-method-cash')), findsOneWidget);

      final cashSwitch = find.byKey(const Key('payment-method-cash'));
      final switchWidget = tester.widget<Switch>(
        find.descendant(of: cashSwitch, matching: find.byType(Switch)).last,
      );
      expect(switchWidget.value, isTrue,
          reason:
              'CASH switch must start ON when editing an announcement with CASH');
      // Toggle ON dès l'ouverture → l'encart commission est visible.
      expect(find.byType(CashCommissionNotice), findsOneWidget);
    },
  );
}
