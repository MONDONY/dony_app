// Tests pour CreateAnnouncementBottomSheet.
// Le bottom sheet utilise GetIt pour AnnouncementBloc et CommissionMethodBloc,
// GoRouter pour les navigations, et AuthBloc dans l'arbre via PrixConditionsStep.
// Ces tests vérifient que le sheet peut s'afficher (étape 0) et que les
// interactions de base (navigation entre étapes, bouton Continuer) fonctionnent.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
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
import 'package:dony/features/matching/data/models/address_suggestion.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trajet_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
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

class MockCitySearchBloc extends MockBloc<CitySearchEvent, CitySearchState>
    implements CitySearchBloc {}

class MockAddressAutocompleteService extends Mock
    implements AddressAutocompleteService {}

class MockCityRepository extends Mock implements CityRepository {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _stripeUser = UserModel(
  id: 'u1',
  roles: const [],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  stripeAccountStatus: 'ONBOARDING_COMPLETE',
);

// ── Builder ───────────────────────────────────────────────────────────────────

/// Construit un écran minimal avec un bouton qui ouvre le bottom sheet.
Widget _buildHost({
  required MockAnnouncementBloc announcementBloc,
  required MockCommissionMethodBloc commissionBloc,
  required MockAuthBloc authBloc,
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
                CreateAnnouncementBottomSheet.show(ctx);
              },
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/announcements',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('Announcements')),
        ),
      ),
      GoRoute(
        path: '/connect/onboarding/intro',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('Stripe onboarding')),
        ),
      ),
      GoRoute(
        path: '/payments/commission-method',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('Commission')),
        ),
      ),
      GoRoute(
        path: '/profile/upgrade-to-pro',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('Upgrade')),
        ),
      ),
    ],
  );
  // AuthBloc est fourni au niveau root (au-dessus de MaterialApp.router) pour que
  // les sheets ouverts avec useRootNavigator: true puissent y accéder.
  return BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const _settle = Duration(milliseconds: 600);

void main() {
  late MockAnnouncementBloc announcementBloc;
  late MockCommissionMethodBloc commissionBloc;
  late MockAuthBloc authBloc;
  late MockCityRepository cityRepo;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(AnnouncementListRequested());
    registerFallbackValue(CommissionMethodInitial());

    cityRepo = MockCityRepository();
    when(() => cityRepo.searchCities(any())).thenAnswer((_) async => []);
    when(() => cityRepo.getPopularCorridors()).thenAnswer((_) async => []);

    // GetIt registrations requises par le bottom sheet
    if (!getIt.isRegistered<CitySearchBloc>()) {
      getIt.registerFactory<CitySearchBloc>(() => CitySearchBloc(cityRepo));
    }
  });

  tearDownAll(() {
    // Ne pas appeler getIt.reset() ici — d'autres tests du même run en ont besoin.
    if (getIt.isRegistered<AddressAutocompleteService>()) {
      getIt.unregister<AddressAutocompleteService>();
    }
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<CommissionMethodBloc>()) {
      getIt.unregister<CommissionMethodBloc>();
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

    final autocomplete = MockAddressAutocompleteService();
    when(() => autocomplete.search(any(), any()))
        .thenAnswer((_) async => const <AddressSuggestion>[]);

    // Enregistrer/remplacer les singletons GetIt pour ce test
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
  });

  tearDown(() {
    announcementBloc.close();
    commissionBloc.close();
    authBloc.close();
    if (getIt.isRegistered<AddressAutocompleteService>()) {
      getIt.unregister<AddressAutocompleteService>();
    }
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<CommissionMethodBloc>()) {
      getIt.unregister<CommissionMethodBloc>();
    }
  });

  group('CreateAnnouncementBottomSheet — création (mode normal)', () {
    testWidgets('le bottom sheet s\'ouvre et affiche l\'étape Trajet',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildHost(
        announcementBloc: announcementBloc,
        commissionBloc: commissionBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_settle);

      // Ouvrir le sheet
      await tester.tap(find.byKey(const Key('open-sheet-btn')));
      await tester.pump(_settle);
      await tester.pump(_settle);

      // Le sheet est ouvert — TrajetStep est visible
      expect(find.byType(TrajetStep), findsOneWidget);
    });

    testWidgets('le stepper header est visible avec les 3 étapes', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildHost(
        announcementBloc: announcementBloc,
        commissionBloc: commissionBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_settle);

      await tester.tap(find.byKey(const Key('open-sheet-btn')));
      await tester.pump(_settle);
      await tester.pump(_settle);

      // Labels du stepper
      expect(find.text('Trajet'), findsAtLeastNWidgets(1));
      expect(find.text('Lieux & capacité'), findsOneWidget);
      expect(find.text('Prix & conditions'), findsOneWidget);
    });

    testWidgets('le titre du sheet est "Publier un trajet"', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildHost(
        announcementBloc: announcementBloc,
        commissionBloc: commissionBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_settle);

      await tester.tap(find.byKey(const Key('open-sheet-btn')));
      await tester.pump(_settle);
      await tester.pump(_settle);

      expect(find.text('Publier un trajet'), findsOneWidget);
    });

    testWidgets('le bouton "Continuer" est présent à l\'étape 0', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildHost(
        announcementBloc: announcementBloc,
        commissionBloc: commissionBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_settle);

      await tester.tap(find.byKey(const Key('open-sheet-btn')));
      await tester.pump(_settle);
      await tester.pump(_settle);

      expect(find.text('Continuer'), findsOneWidget);
    });

    testWidgets('tap sur "Continuer" avance à l\'étape 1 (Lieux & capacité)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildHost(
        announcementBloc: announcementBloc,
        commissionBloc: commissionBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_settle);

      await tester.tap(find.byKey(const Key('open-sheet-btn')));
      await tester.pump(_settle);
      await tester.pump(_settle);

      // Cliquer "Continuer"
      await tester.tap(find.text('Continuer'));
      await tester.pump(_settle);

      // Maintenant à l'étape 1 — "Retour" est visible
      expect(find.text('Retour'), findsOneWidget);
    });

    testWidgets('tap sur "Continuer" deux fois atteint l\'étape 2 (Prix)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildHost(
        announcementBloc: announcementBloc,
        commissionBloc: commissionBloc,
        authBloc: authBloc,
      ));
      await tester.pump(_settle);

      await tester.tap(find.byKey(const Key('open-sheet-btn')));
      await tester.pump(_settle);
      await tester.pump(_settle);

      // Étape 0 → 1
      await tester.tap(find.text('Continuer'));
      await tester.pump(_settle);

      // Étape 1 → 2
      await tester.tap(find.text('Continuer'));
      await tester.pump(_settle);
      await tester.pump(_settle);

      // À l'étape 2, le bouton Aperçu ou Enregistrer apparaît
      // (dépend de l'état authBloc/stripeConfigured)
      expect(
        find.byKey(const Key('create-announcement-preview')).evaluate().isNotEmpty ||
        find.byKey(const Key('configure-stripe-btn')).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
