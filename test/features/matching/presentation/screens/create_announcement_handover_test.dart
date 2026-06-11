import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/address_suggestion.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/screens/create_announcement_screen.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class MockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

class MockAddressAutocompleteService extends Mock
    implements AddressAutocompleteService {}

class MockCityRepository extends Mock implements CityRepository {}

class MockTripTemplateBloc
    extends MockBloc<TripTemplateEvent, TripTemplateState>
    implements TripTemplateBloc {}

MockTripTemplateBloc _stubTemplateBloc() {
  final bloc = MockTripTemplateBloc();
  when(() => bloc.state).thenReturn(const TripTemplateState());
  when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  return bloc;
}

const _pickup = AddressData(label: '12 rue de Paris, Paris', lat: 48.85, lng: 2.35);
const _delivery = AddressData(label: '5 rue Dakar, Dakar', lat: 14.69, lng: -17.44);

AnnouncementModel _editAnnouncement({DateTime? handoverStart, DateTime? handoverEnd}) =>
    AnnouncementModel(
      id: 'ann-hw-1',
      travelerId: 'trav-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 8, 20),
      pickupAddress: _pickup,
      deliveryAddress: _delivery,
      availableKg: 10,
      totalKg: 10,
      pricePerKg: 6,
      transportMode: TransportMode.plane,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      handoverWindowStart: handoverStart,
      handoverWindowEnd: handoverEnd,
    );

Widget _buildScreen(
  MockAnnouncementBloc bloc, {
  AnnouncementModel? announcement,
  MockCommissionMethodBloc? commissionBloc,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => MultiBlocProvider(
          providers: [
            BlocProvider<AnnouncementBloc>.value(value: bloc),
            if (commissionBloc != null)
              BlocProvider<CommissionMethodBloc>.value(value: commissionBloc),
            BlocProvider<TripTemplateBloc>(create: (_) => _stubTemplateBloc()),
          ],
          child: CreateAnnouncementScreen(announcement: announcement),
        ),
      ),
      GoRoute(
        path: '/announcements',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Announcements list'))),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light);
}

Future<void> _pumpScreen(
  WidgetTester tester,
  MockAnnouncementBloc bloc, {
  AnnouncementModel? announcement,
  MockCommissionMethodBloc? commissionBloc,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_buildScreen(
    bloc,
    announcement: announcement,
    commissionBloc: commissionBloc,
  ));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  late MockAnnouncementBloc bloc;
  late MockCommissionMethodBloc commissionBloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(AnnouncementListRequested());
    registerFallbackValue(CommissionMethodInitial());
    registerFallbackValue(AnnouncementCreateRequested(
      departureCity: '',
      arrivalCity: '',
      departureDate: DateTime(2026),
      pickupAddress: const AddressData(label: '', lat: 0, lng: 0),
      deliveryAddress: const AddressData(label: '', lat: 0, lng: 0),
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
      pickupAddress: const AddressData(label: '', lat: 0, lng: 0),
      deliveryAddress: const AddressData(label: '', lat: 0, lng: 0),
      availableKg: 0,
      pricePerKg: 0,
      transportMode: TransportMode.plane,
      handoverWindowStart: DateTime(2026, 6, 14, 16),
      handoverWindowEnd: DateTime(2026, 6, 14, 18),
    ));

    final mockCityRepo = MockCityRepository();
    when(() => mockCityRepo.searchCities(any())).thenAnswer((_) async => []);
    when(() => mockCityRepo.getPopularCorridors()).thenAnswer((_) async => []);
    if (!getIt.isRegistered<CitySearchBloc>()) {
      getIt.registerFactory<CitySearchBloc>(() => CitySearchBloc(mockCityRepo));
    }
  });

  tearDownAll(() {
    getIt.reset();
  });

  setUp(() {
    bloc = MockAnnouncementBloc();
    when(() => bloc.state).thenReturn(AnnouncementInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    commissionBloc = MockCommissionMethodBloc();
    when(() => commissionBloc.state).thenReturn(CommissionMethodNotConfigured());
    when(() => commissionBloc.stream).thenAnswer((_) => const Stream.empty());

    final autocomplete = MockAddressAutocompleteService();
    when(() => autocomplete.search(any(), any()))
        .thenAnswer((_) async => const <AddressSuggestion>[]);
    if (getIt.isRegistered<AddressAutocompleteService>()) {
      getIt.unregister<AddressAutocompleteService>();
    }
    getIt.registerSingleton<AddressAutocompleteService>(autocomplete);
  });

  tearDown(() {
    bloc.close();
    if (getIt.isRegistered<AddressAutocompleteService>()) {
      getIt.unregister<AddressAutocompleteService>();
    }
  });

  // ── 1. Rows présentes ─────────────────────────────────────────────────────────────

  testWidgets('handover_rows_present: les deux rows debut/fin sont affichées', (tester) async {
    await _pumpScreen(tester, bloc, commissionBloc: commissionBloc);

    expect(find.byKey(const Key('handover-start-row')), findsOneWidget);
    expect(find.byKey(const Key('handover-end-row')), findsOneWidget);
  });

  // ── 2. Validation bloquante ───────────────────────────────────────────────

  testWidgets(
    'handover_required: submit bloque si la fenêtre de remise est absente',
    (tester) async {
      when(() => bloc.add(any())).thenReturn(null);

      // Use edit mode with all required fields filled (city, date, addresses,
      // transport), but WITHOUT handover dates — this isolates the handover
      // validation check.
      await _pumpScreen(
        tester,
        bloc,
        announcement: _editAnnouncement(), // handoverStart/End are null
        commissionBloc: commissionBloc,
      );

      final submitBtn = find.byKey(const Key('create-announcement-submit'));
      expect(submitBtn, findsOneWidget);

      // In edit mode the button is active (transport already set)
      final btn = tester.widget<DonyButton>(submitBtn);
      expect(btn.onPressed, isNotNull);

      // Tapper submit sans fenêtre définie
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // L'erreur snackbar apparaît
      expect(find.text('Fenêtre de remise obligatoire'), findsOneWidget);

      // Aucun AnnouncementUpdateRequested dispatché
      verifyNever(() => bloc.add(any(that: isA<AnnouncementUpdateRequested>())));
    },
  );

  // ── 3. Submit positif en mode édition ────────────────────────────────────────────

  testWidgets(
    'submit en édition forwarde la fenêtre de remise au bloc',
    (tester) async {
      when(() => bloc.add(any())).thenReturn(null);

      final start = DateTime(2026, 6, 14, 16);
      final end = DateTime(2026, 6, 14, 18);

      // Departure is 2026-08-20 — well after the handover window, so
      // end <= departure validation passes.
      await _pumpScreen(
        tester,
        bloc,
        announcement: _editAnnouncement(handoverStart: start, handoverEnd: end),
        commissionBloc: commissionBloc,
      );

      final submitBtn = find.byKey(const Key('create-announcement-submit'));
      expect(submitBtn, findsOneWidget);

      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // No error snackbar
      expect(find.text('Fenêtre de remise obligatoire'), findsNothing);

      // AnnouncementUpdateRequested dispatched with the correct window
      verify(
        () => bloc.add(
          any(
            that: isA<AnnouncementUpdateRequested>()
                .having(
                  (e) => e.handoverWindowStart,
                  'handoverWindowStart',
                  start,
                )
                .having(
                  (e) => e.handoverWindowEnd,
                  'handoverWindowEnd',
                  end,
                ),
          ),
        ),
      ).called(1);
    },
  );

  // ── 4. Edit mode prefill ──────────────────────────────────────────────────────────

  testWidgets(
    'handover_edit_prefill: mode édition préremplit les valeurs existantes',
    (tester) async {
      final start = DateTime(2026, 8, 20, 14, 0);
      final end = DateTime(2026, 8, 20, 16, 0);
      await _pumpScreen(
        tester,
        bloc,
        announcement: _editAnnouncement(handoverStart: start, handoverEnd: end),
        commissionBloc: commissionBloc,
      );

      // Les deux rows doivent afficher les dates formatées (pas 'Choisir')
      expect(find.text('Choisir'), findsNothing);
    },
  );
}
