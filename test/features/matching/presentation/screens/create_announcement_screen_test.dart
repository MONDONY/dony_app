import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
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

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class MockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

class MockAddressAutocompleteService extends Mock
    implements AddressAutocompleteService {}

class MockCityRepository extends Mock implements CityRepository {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

class MockTripTemplateBloc
    extends MockBloc<TripTemplateEvent, TripTemplateState>
    implements TripTemplateBloc {}

MockTripTemplateBloc _stubTemplateBloc() {
  final bloc = MockTripTemplateBloc();
  when(() => bloc.state).thenReturn(const TripTemplateState());
  when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  return bloc;
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _pickup =
    AddressData(label: '12 rue de Paris, Paris', lat: 48.85, lng: 2.35);
const _delivery =
    AddressData(label: '5 rue Dakar, Dakar', lat: 14.69, lng: -17.44);

AnnouncementModel _editingAnnouncement({
  TransportMode? mode = TransportMode.train,
}) =>
    AnnouncementModel(
      id: 'ann-1',
      travelerId: 'trav-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 6, 15),
      pickupAddress: _pickup,
      deliveryAddress: _delivery,
      availableKg: 12,
      totalKg: 12,
      pricePerKg: 6,
      transportMode: mode,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

// ── Builder ───────────────────────────────────────────────────────────────────

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

// ── Helpers ───────────────────────────────────────────────────────────────────

const _kSettle = Duration(milliseconds: 600);

Future<void> _pumpScreen(
  WidgetTester tester,
  MockAnnouncementBloc bloc, {
  AnnouncementModel? announcement,
  MockCommissionMethodBloc? commissionBloc,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_buildScreen(
    bloc,
    announcement: announcement,
    commissionBloc: commissionBloc,
  ));
  await tester.pump(_kSettle);
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late MockAnnouncementBloc bloc;
  late MockCommissionMethodBloc commissionBloc;
  late MockAddressAutocompleteService autocomplete;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(AnnouncementListRequested());
    registerFallbackValue(CommissionMethodInitial());
    // CitySearchBloc needed: CreateAnnouncementScreen uses getIt<CitySearchBloc>()
    final mockCityRepo = MockCityRepository();
    when(() => mockCityRepo.searchCities(any())).thenAnswer((_) async => []);
    when(() => mockCityRepo.getPopularCorridors()).thenAnswer((_) async => []);
    getIt.registerFactory<CitySearchBloc>(() => CitySearchBloc(mockCityRepo));
    getIt.registerFactory<IContentCategoryRepository>(
      () => _FakeContentCategoryRepository(),
    );
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

    autocomplete = MockAddressAutocompleteService();
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

  // ── 1. Rendu chips ────────────────────────────────────────────────────────

  testWidgets('affiche les 6 chips de mode de transport avec leurs icônes',
      (tester) async {
    await _pumpScreen(tester, bloc, commissionBloc: commissionBloc);

    // Scroll the section into view
    final firstChip =
        find.byKey(const Key('transport-chip-plane'));
    await tester.scrollUntilVisible(
      firstChip,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    for (final mode in TransportMode.values) {
      expect(find.byKey(Key('transport-chip-${mode.name}')), findsOneWidget,
          reason: 'chip ${mode.name} manquant');
    }
    // Au moins une icône d'avion (du chip plane)
    expect(find.byIcon(Icons.flight_rounded), findsAtLeastNWidgets(1));
    // Section label rendu
    expect(find.text('MODE DE TRANSPORT'), findsOneWidget);
  });

  // ── 2. Submit gating ───────────────────────────────────────────────────────

  testWidgets(
      'bouton submit désactivé tant qu\'aucun mode de transport n\'est sélectionné',
      (tester) async {
    await _pumpScreen(tester, bloc, commissionBloc: commissionBloc);

    final submitFinder = find.byKey(const Key('create-announcement-submit'));

    // Initially disabled (no transport mode picked)
    var btn = tester.widget<DonyButton>(submitFinder);
    expect(btn.onPressed, isNull);

    // Scroll to chip and tap plane
    final planeChip = find.byKey(const Key('transport-chip-plane'));
    await tester.scrollUntilVisible(
      planeChip,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(planeChip);
    await tester.pump();

    btn = tester.widget<DonyButton>(submitFinder);
    expect(btn.onPressed, isNotNull);
  });

  // ── 3. Edit mode pré-sélection ────────────────────────────────────────────

  testWidgets('mode édition pré-sélectionne le mode de transport existant',
      (tester) async {
    await _pumpScreen(
      tester,
      bloc,
      announcement: _editingAnnouncement(mode: TransportMode.train),
      commissionBloc: commissionBloc,
    );

    // Scroll the chip section into view
    final trainChip = find.byKey(const Key('transport-chip-train'));
    await tester.scrollUntilVisible(
      trainChip,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    // En édition, le bouton submit doit être actif dès l'ouverture
    final btn = tester.widget<DonyButton>(
        find.byKey(const Key('create-announcement-submit')));
    expect(btn.onPressed, isNotNull);

    // Le label "Train" doit être visible (chip rendu)
    expect(find.text('Train'), findsOneWidget);
  });

  // ── 4. Écran de succès (DonySuccessScreen) ────────────────────────────────

  group('CreateAnnouncementScreen — BLoC listener (succès)', () {
    late StreamController<AnnouncementState> annStreamCtrl;

    setUp(() {
      annStreamCtrl = StreamController<AnnouncementState>.broadcast();
      when(() => bloc.stream).thenAnswer((_) => annStreamCtrl.stream);
    });

    tearDown(() async {
      await annStreamCtrl.close();
    });

    testWidgets(
        'AnnouncementCreated affiche DonySuccessScreen (mode création)',
        (tester) async {
      await _pumpScreen(tester, bloc, commissionBloc: commissionBloc);

      annStreamCtrl.add(AnnouncementCreated(_editingAnnouncement()));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(DonySuccessScreen), findsOneWidget);
      expect(find.text('Trajet publié !'), findsOneWidget);
    });

    testWidgets(
        'AnnouncementUpdated affiche DonySuccessScreen (mode édition)',
        (tester) async {
      await _pumpScreen(
        tester,
        bloc,
        announcement: _editingAnnouncement(),
        commissionBloc: commissionBloc,
      );

      annStreamCtrl.add(AnnouncementUpdated(_editingAnnouncement()));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(DonySuccessScreen), findsOneWidget);
      expect(find.text('Trajet modifié !'), findsOneWidget);
    });

    testWidgets(
        'le CTA de DonySuccessScreen navigue vers /announcements sans throw',
        (tester) async {
      await _pumpScreen(tester, bloc, commissionBloc: commissionBloc);

      annStreamCtrl.add(AnnouncementCreated(_editingAnnouncement()));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(DonySuccessScreen), findsOneWidget);

      // Ne doit pas jeter (bug de contexte désactivé, même classe que le
      // fix task 4/6) et doit atterrir sur la liste des annonces.
      await tester.tap(find.text('Voir mon trajet'));
      await tester.pumpAndSettle();

      expect(find.text('Announcements list'), findsOneWidget);
    });
  });
}
