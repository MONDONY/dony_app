// Tests pour le flux « trajet dédié » de CreateAnnouncementBottomSheet
// (ouverture avec un lockContext, côté voyageur depuis « Lier un trajet »).
//
// Depuis la refonte Q2, ce flux passe par le MÊME wizard 3 étapes que la
// création/modification, avec des champs verrouillés :
//   - corridor (villes) verrouillé, date éditable dans la fenêtre de tolérance
//   - capacité verrouillée (affichage en lecture seule, fixée par la demande)
//   - prix verrouillé → carte « Prix total convenu »
//   - section « Modes de paiement » masquée (mode déjà fixé par la négociation)
//
// Les étapes sont gardées dans l'arbre via Offstage : on vérifie le contenu
// des étapes 1 et 2 dès l'étape 0 avec skipOffstage:false.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
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
import 'package:dony/features/matching/data/models/address_suggestion.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/capacity_control.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/lieux_capacite_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trajet_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/locked_trip_context.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
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

class MockAnnouncementBloc extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class MockTripTemplateBloc
    extends MockBloc<TripTemplateEvent, TripTemplateState>
    implements TripTemplateBloc {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

class MockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

class MockNegotiationBloc
    extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

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

// desiredDate très au-delà de "aujourd'hui" → fenêtre de tolérance ouvrable.
final _lockContext = LockedTripContext(
  threadId: 't1',
  packageRequestId: 'pr1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: DateTime(2026, 8, 15),
  dateToleranceDays: 3,
  weightKg: 15,
  transportMode: TransportMode.plane,
  agreedPriceEur: 150,
  paymentMethod: PaymentMethod.stripe,
);

// ── Builder ───────────────────────────────────────────────────────────────────

Widget _buildHost({
  required MockNegotiationBloc negotiationBloc,
  required MockAuthBloc authBloc,
  required MockStripeAccountBloc stripeBloc,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open-dedicated-sheet-btn'),
              onPressed: () {
                CreateAnnouncementBottomSheet.show(
                  ctx,
                  lockContext: _lockContext,
                  negotiationBloc: negotiationBloc,
                );
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

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-dedicated-sheet-btn')));
  await tester.pump(_settle);
  await tester.pump(_settle);
}

void main() {
  late MockAnnouncementBloc announcementBloc;
  late MockCommissionMethodBloc commissionBloc;
  late MockAuthBloc authBloc;
  late MockStripeAccountBloc stripeBloc;
  late MockNegotiationBloc negotiationBloc;
  late MockCityRepository cityRepo;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(AnnouncementListRequested());
    registerFallbackValue(CommissionMethodInitial());

    cityRepo = MockCityRepository();
    when(() => cityRepo.searchCities(any())).thenAnswer((_) async => []);
    when(() => cityRepo.getPopularCorridors()).thenAnswer((_) async => []);

    if (!getIt.isRegistered<CitySearchBloc>()) {
      getIt.registerFactory<CitySearchBloc>(() => CitySearchBloc(cityRepo));
    }
    if (!getIt.isRegistered<TripTemplateBloc>()) {
      getIt.registerFactory<TripTemplateBloc>(() {
        final bloc = MockTripTemplateBloc();
        when(() => bloc.state).thenReturn(const TripTemplateState());
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
        return bloc;
      });
    }
    // Le bottom sheet charge le catalogue de types de contenu via getIt.
    if (!getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.registerFactory<IContentCategoryRepository>(
        () => _FakeContentCategoryRepository(),
      );
    }
  });

  tearDownAll(() {
    for (final unregister in [
      () => getIt.unregister<AddressAutocompleteService>(),
      () => getIt.unregister<AnnouncementBloc>(),
      () => getIt.unregister<CommissionMethodBloc>(),
      () => getIt.unregister<PriceGridRepository>(),
    ]) {
      try {
        unregister();
      } catch (_) {/* déjà désenregistré */}
    }
  });

  setUp(() {
    announcementBloc = MockAnnouncementBloc();
    when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
    when(() => announcementBloc.stream).thenAnswer((_) => const Stream.empty());

    commissionBloc = MockCommissionMethodBloc();
    when(() => commissionBloc.state).thenReturn(CommissionMethodNotConfigured());
    when(() => commissionBloc.stream).thenAnswer((_) => const Stream.empty());

    authBloc = MockAuthBloc();
    when(() => authBloc.state).thenReturn(AuthAuthenticated(_stripeUser));
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());

    stripeBloc = MockStripeAccountBloc();
    when(() => stripeBloc.state).thenReturn(StripeAccountReady(
      const ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
    ));
    when(() => stripeBloc.stream).thenAnswer((_) => const Stream.empty());

    negotiationBloc = MockNegotiationBloc();
    when(() => negotiationBloc.state).thenReturn(const NegotiationInitial());
    when(() => negotiationBloc.stream)
        .thenAnswer((_) => const Stream.empty());

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
    negotiationBloc.close();
  });

  void _setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('CreateAnnouncementBottomSheet — trajet dédié (lockContext)', () {
    testWidgets('le titre est "Créer le trajet pour cette demande"',
        (tester) async {
      _setLargeScreen(tester);
      await tester.pumpWidget(_buildHost(
        negotiationBloc: negotiationBloc,
        authBloc: authBloc,
        stripeBloc: stripeBloc,
      ));
      await tester.pump(_settle);
      await _openSheet(tester);

      expect(find.text('Créer le trajet pour cette demande'), findsOneWidget);
    });

    testWidgets('affiche le wizard 3 étapes (TrajetStep + bannière verrouillée)',
        (tester) async {
      _setLargeScreen(tester);
      await tester.pumpWidget(_buildHost(
        negotiationBloc: negotiationBloc,
        authBloc: authBloc,
        stripeBloc: stripeBloc,
      ));
      await tester.pump(_settle);
      await _openSheet(tester);

      // Wizard (et non plus le formulaire plat) → TrajetStep présent.
      expect(find.byType(TrajetStep), findsOneWidget);
      // Bannière du trajet dédié.
      expect(find.text('Trajet dédié à la demande'), findsOneWidget);
      expect(
        find.textContaining('Corridor, capacité et prix sont verrouillés'),
        findsOneWidget,
      );
      // Étape 0 active → bouton Continuer (corridor + date pré-remplis).
      expect(find.text('Continuer'), findsOneWidget);
    });

    testWidgets('le corridor est pré-rempli et verrouillé (Paris → Dakar)',
        (tester) async {
      _setLargeScreen(tester);
      await tester.pumpWidget(_buildHost(
        negotiationBloc: negotiationBloc,
        authBloc: authBloc,
        stripeBloc: stripeBloc,
      ));
      await tester.pump(_settle);
      await _openSheet(tester);

      // Champs ville pré-remplis (DonyTextField.tappable en lecture seule).
      expect(find.byKey(const Key('departureCityField')), findsOneWidget);
      expect(find.byKey(const Key('arrivalCityField')), findsOneWidget);
      expect(find.text('Paris'), findsWidgets);
      expect(find.text('Dakar'), findsWidgets);
      // Aperçu corridor « Confirmé ».
      expect(find.text('Confirmé'), findsOneWidget);
    });

    testWidgets('la date reste éditable (tap ouvre le sélecteur de date)',
        (tester) async {
      _setLargeScreen(tester);
      await tester.pumpWidget(_buildHost(
        negotiationBloc: negotiationBloc,
        authBloc: authBloc,
        stripeBloc: stripeBloc,
      ));
      await tester.pump(_settle);
      await _openSheet(tester);

      await tester.tap(find.byKey(const Key('departureDateField')));
      await tester.pumpAndSettle();

      // Le sélecteur de date Material est ouvert (bouton OK présent).
      expect(find.text('OK'), findsOneWidget);
      // Refermer pour ne pas laisser de dialog ouvert.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'la capacité est verrouillée (affichage lecture seule, pas de CapacityControl)',
        (tester) async {
      _setLargeScreen(tester);
      await tester.pumpWidget(_buildHost(
        negotiationBloc: negotiationBloc,
        authBloc: authBloc,
        stripeBloc: stripeBloc,
      ));
      await tester.pump(_settle);
      await _openSheet(tester);

      // L'étape 1 est dans l'arbre (Offstage) → on la trouve avec skipOffstage.
      expect(
        find.byKey(const Key('locked-capacity-display'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Capacité fixée par la demande', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('15 kg', skipOffstage: false), findsOneWidget);
      // Le contrôle de capacité interactif n'est PAS utilisé en dédié.
      expect(find.byType(CapacityControl, skipOffstage: false), findsNothing);
    });

    testWidgets(
        'le prix est verrouillé → carte « Prix total convenu » (150 €)',
        (tester) async {
      _setLargeScreen(tester);
      await tester.pumpWidget(_buildHost(
        negotiationBloc: negotiationBloc,
        authBloc: authBloc,
        stripeBloc: stripeBloc,
      ));
      await tester.pump(_settle);
      await _openSheet(tester);

      expect(
        find.byKey(const Key('locked-agreed-price-card'), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Prix total convenu', skipOffstage: false),
          findsOneWidget);
      expect(find.text('150 €', skipOffstage: false), findsOneWidget);
    });

    testWidgets('la section « Modes de paiement » est masquée', (tester) async {
      _setLargeScreen(tester);
      await tester.pumpWidget(_buildHost(
        negotiationBloc: negotiationBloc,
        authBloc: authBloc,
        stripeBloc: stripeBloc,
      ));
      await tester.pump(_settle);
      await _openSheet(tester);

      // Même en cherchant dans les étapes off-stage, aucun toggle de paiement.
      expect(
        find.byKey(const Key('payment-method-stripe'), skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byKey(const Key('payment-method-cash'), skipOffstage: false),
        findsNothing,
      );
      expect(find.text('Modes de paiement acceptés', skipOffstage: false),
          findsNothing);
    });

    testWidgets(
        'tap "Continuer" avance à l\'étape Lieux & capacité (verrouillée)',
        (tester) async {
      _setLargeScreen(tester);
      await tester.pumpWidget(_buildHost(
        negotiationBloc: negotiationBloc,
        authBloc: authBloc,
        stripeBloc: stripeBloc,
      ));
      await tester.pump(_settle);
      await _openSheet(tester);

      // Fenêtre de remise requise pour activer « Continuer ». Le picker propose
      // le lendemain à 16:00 / 18:00 (avant la date de départ verrouillée) →
      // accepter via OK suffit à produire une fenêtre valide.
      await tester.tap(find.byKey(const Key('sheet-handover-start-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // date
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // heure (16:00)
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet-handover-end-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // date
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // heure (18:00)
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuer'));
      await tester.pump(_settle);
      await tester.pump(_settle);

      // À l'étape 1, le bouton "Retour" apparaît et l'étape Lieux & capacité
      // est désormais à l'écran (LieuxCapaciteStep + capacité verrouillée).
      expect(find.text('Retour'), findsOneWidget);
      expect(find.byType(LieuxCapaciteStep), findsOneWidget);
      expect(find.byKey(const Key('locked-capacity-display')), findsOneWidget);
    });
  });
}
