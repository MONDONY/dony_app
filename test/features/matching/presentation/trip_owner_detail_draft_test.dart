// Task 5 (trip-draft-status) — écran détail propriétaire d'un trajet.
//
// Couvre :
//  - Bannière « brouillon » + tuile « Publier » visibles uniquement pour un
//    trajet DRAFT (jamais pour un trajet ACTIVE).
//  - Tap sur « Publier » → dispatch AnnouncementPublishRequested(id).
//  - Gating édition/suppression : un DRAFT à 0 demande reste modifiable ET
//    supprimable (le backend autorise désormais la suppression d'un brouillon).
//
// Pattern de harnais repris de
// test/features/matching/presentation/screens/trip_owner_detail_screen_test.dart
// (MockBloc mocktail + MultiBlocProvider + GoRouter minimal).

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:dony/features/gp_pro/data/repositories/gp_pro_repository.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/trip_owner_detail_screen.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/features/traveler_status/bloc/traveler_status_cubit.dart';
import 'package:dony/features/traveler_status/data/publishing_eligibility.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_declaration.dart';
import 'package:dony/features/traveler_status/data/traveler_status_repository.dart';
import 'package:dony/features/traveler_status/presentation/publish_blocked_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/stripe_account_test_doubles.dart';
import '../../../helpers/trip_answer_blocs.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockTripAudienceCubit extends MockCubit<TripAudienceState>
    implements TripAudienceCubit {}

/// Audience masquée : ces tests ne portent pas sur la carte d'audience.
TripAudienceCubit _hiddenAudience() {
  final cubit = _MockTripAudienceCubit();
  when(() => cubit.state).thenReturn(const TripAudienceState.hidden());
  when(() => cubit.load(any())).thenAnswer((_) async {});
  return cubit;
}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

/// « Je pars » : l'écran fournit son cubit (getIt) ; ces tests ne partent pas.
class _MockTripDepartCubit extends MockCubit<TripDepartState>
    implements TripDepartCubit {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _ownerId = 'trav-001';

/// Propriétaire qui a déjà déclaré son statut : « Publier » part tout de suite.
const _owner = UserModel(
  id: _ownerId,
  roles: [],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  travelerStatus: TravelerStatus.individual,
);

/// Propriétaire qui n'a pas encore répondu à « Comment voyagez-vous ? ».
const _ownerUndeclared = UserModel(
  id: _ownerId,
  roles: [],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

class _MockTravelerStatusRepository extends Mock
    implements TravelerStatusRepository {}

class _MockGpProRepository extends Mock implements GpProRepository {}

AnnouncementModel _makeAnnouncement({
  String status = 'ACTIVE',
  int? bidsCount = 0,
}) => AnnouncementModel(
  id: 'ann-trip-001',
  travelerId: _ownerId,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2027, 7),
  availableKg: 10,
  totalKg: 23,
  pricePerKg: 8,
  status: status,
  bidsCount: bidsCount,
  createdAt: DateTime(2026, 6),
  updatedAt: DateTime(2026, 6),
);

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<GoRouter> _pump(
  WidgetTester tester, {
  required _MockAnnouncementBloc annBloc,
  required _MockBidBloc bidBloc,
  required _MockCancellationBloc cancelBloc,
  required _MockAuthBloc authBloc,
  AnnouncementModel? initial,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => MultiBlocProvider(
          providers: [
            BlocProvider<AnnouncementBloc>.value(value: annBloc),
            BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<CancellationBloc>.value(value: cancelBloc),
            BlocProvider<TripAudienceCubit>.value(value: _hiddenAudience()),
            BlocProvider<AuthBloc>.value(value: authBloc),
            // Fourni à l'échelle de l'app dans `app.dart` : le corps de détail
            // le lit pour savoir si Stripe couvre le pays du voyageur.
            BlocProvider<StripeAccountBloc>.value(
              value: stubStripeAccountBloc(),
            ),
          ],
          child: TripOwnerDetailScreen(
            announcementId: 'ann-trip-001',
            initial: initial,
          ),
        ),
      ),
      GoRoute(
        path: '/kyc/status',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('KYC status'))),
      ),
      GoRoute(
        path: '/trips/create',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('Créer / modifier'))),
      ),
      GoRoute(
        path: '/trips/publish-blocked',
        builder: (_, state) {
          final args = state.extra! as PublishBlockedArgs;
          return PublishBlockedScreen(
            eligibility: args.eligibility,
            source: args.source,
          );
        },
      ),
      GoRoute(
        path: '/profile/gp-pro',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: context.pop,
            child: const Text('formulaire GP Pro'),
          ),
        ),
      ),
      GoRoute(
        path: '/profile/upgrade-to-pro',
        builder: (_, _) => const Scaffold(body: Center(child: Text('Upgrade'))),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return router;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _MockAnnouncementBloc annBloc;
  late _MockBidBloc bidBloc;
  late _MockCancellationBloc cancelBloc;
  late _MockAuthBloc authBloc;
  late _MockAnalyticsService analytics;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(AnnouncementDetailRequested(''));
    registerFallbackValue(TravelerStatus.individual);
    registerFallbackValue(const AuthProfileRefreshRequested());
  });

  setUp(() {
    annBloc = _MockAnnouncementBloc();
    bidBloc = _MockBidBloc();
    cancelBloc = _MockCancellationBloc();
    authBloc = _MockAuthBloc();
    when(() => authBloc.isClosed).thenReturn(false);
    analytics = _MockAnalyticsService();

    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logScreen(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    when(() => bidBloc.state).thenReturn(BidListLoaded(const []));
    whenListen(
      bidBloc,
      Stream<BidState>.value(BidListLoaded(const [])),
      initialState: BidListLoaded(const []),
    );
    when(() => cancelBloc.state).thenReturn(CancellationInitial());
    whenListen(
      cancelBloc,
      const Stream<CancellationState>.empty(),
      initialState: CancellationInitial(),
    );

    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthAuthenticated(_owner),
    );

    when(() => annBloc.add(any())).thenReturn(null);
    when(() => annBloc.isClosed).thenReturn(false);

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
    registerInertTripAnswerBlocs();
    if (getIt.isRegistered<TripDepartCubit>()) {
      getIt.unregister<TripDepartCubit>();
    }
    getIt.registerFactoryParam<TripDepartCubit, String, void>((_, _) {
      final cubit = _MockTripDepartCubit();
      whenListen(
        cubit,
        const Stream<TripDepartState>.empty(),
        initialState: const TripDepartState(),
      );
      return cubit;
    });
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    if (getIt.isRegistered<TripDepartCubit>()) {
      getIt.unregister<TripDepartCubit>();
    }
    annBloc.close();
    bidBloc.close();
    cancelBloc.close();
    authBloc.close();
  });

  testWidgets(
    'affiche la bannière brouillon et le bouton Publier pour un DRAFT',
    (tester) async {
      final announcement = _makeAnnouncement(status: 'DRAFT');
      when(
        () => annBloc.state,
      ).thenReturn(AnnouncementDetailLoaded(announcement));
      whenListen(
        annBloc,
        Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
        initialState: AnnouncementDetailLoaded(announcement),
      );

      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('brouillon'), findsWidgets);
      // Pied collant, et grosse carte « À traiter » (« Publier » en tête).
      expect(_inFooter(find.text('Publier')), findsOneWidget);
      expect(find.text('Publier'), findsNWidgets(2));
    },
  );

  testWidgets('pas de bannière ni de bouton Publier pour un trajet ACTIVE', (
    tester,
  ) async {
    final announcement = _makeAnnouncement();
    when(
      () => annBloc.state,
    ).thenReturn(AnnouncementDetailLoaded(announcement));
    whenListen(
      annBloc,
      Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
      initialState: AnnouncementDetailLoaded(announcement),
    );

    await _pump(
      tester,
      annBloc: annBloc,
      bidBloc: bidBloc,
      cancelBloc: cancelBloc,
      authBloc: authBloc,
    );
    await tester.pumpAndSettle();

    expect(find.text('Publier'), findsNothing);
    expect(find.textContaining('brouillon'), findsNothing);
  });

  testWidgets('taper Publier dispatch AnnouncementPublishRequested', (
    tester,
  ) async {
    final announcement = _makeAnnouncement(status: 'DRAFT');
    when(
      () => annBloc.state,
    ).thenReturn(AnnouncementDetailLoaded(announcement));
    whenListen(
      annBloc,
      Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
      initialState: AnnouncementDetailLoaded(announcement),
    );

    await _pump(
      tester,
      annBloc: annBloc,
      bidBloc: bidBloc,
      cancelBloc: cancelBloc,
      authBloc: authBloc,
    );
    await tester.pumpAndSettle();

    await tester.tap(_inFooter(find.text('Publier')));
    await tester.pump();

    verify(
      () => annBloc.add(
        any(
          that: predicate<AnnouncementEvent>(
            (e) => e is AnnouncementPublishRequested && e.id == announcement.id,
            'AnnouncementPublishRequested(${announcement.id})',
          ),
        ),
      ),
    ).called(1);
  });

  testWidgets(
    'un DRAFT à 0 demande reste modifiable et supprimable (tuiles actives)',
    (tester) async {
      final announcement = _makeAnnouncement(status: 'DRAFT');
      when(
        () => annBloc.state,
      ).thenReturn(AnnouncementDetailLoaded(announcement));
      whenListen(
        annBloc,
        Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
        initialState: AnnouncementDetailLoaded(announcement),
      );

      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();

      // « Modifier » au pied, à côté de « Publier », et actif.
      final edit = tester.widget<DonyButton>(
        find.byKey(const Key('trip-footer-edit')),
      );
      expect(
        edit.onPressed,
        isNotNull,
        reason: 'Modifier doit être actif pour un DRAFT à 0 demande',
      );

      // « Supprimer » au menu ⋮ (le backend autorise la suppression d'un
      // DRAFT), « Modifier » aussi.
      await tester.tap(find.byKey(const Key('trip-owner-menu-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trip-menu-delete')), findsOneWidget);
      expect(find.byKey(const Key('trip-menu-edit')), findsOneWidget);
    },
  );

  testWidgets(
    'l\'écran affiche le badge « Brouillon » dans le détail pour un DRAFT',
    (tester) async {
      final announcement = _makeAnnouncement(status: 'DRAFT');
      when(
        () => annBloc.state,
      ).thenReturn(AnnouncementDetailLoaded(announcement));
      whenListen(
        annBloc,
        Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
        initialState: AnnouncementDetailLoaded(announcement),
      );

      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('BROUILLON'), findsOneWidget);
    },
  );

  testWidgets(
    'après publication (AnnouncementPublished sans reload), la bannière '
    'brouillon et la tuile Publier disparaissent',
    (tester) async {
      final draft = _makeAnnouncement(status: 'DRAFT');
      final published = _makeAnnouncement();

      // État initial : DetailLoaded en DRAFT, ET widget.initial passé en DRAFT
      // (comme lors d'une navigation depuis la liste avec `extra:`), pour
      // reproduire le repli sur `widget.initial` figé si le rechargement
      // déclenché après publication n'aboutit pas.
      when(() => annBloc.state).thenReturn(AnnouncementDetailLoaded(draft));
      final controller = StreamController<AnnouncementState>();
      whenListen(
        annBloc,
        controller.stream,
        initialState: AnnouncementDetailLoaded(draft),
      );
      addTearDown(controller.close);

      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
        initial: draft,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('brouillon'), findsWidgets);
      // Pied collant, et grosse carte « À traiter » (« Publier » en tête).
      expect(_inFooter(find.text('Publier')), findsOneWidget);
      expect(find.text('Publier'), findsNWidgets(2));

      // Le bloc émet l'état intermédiaire AnnouncementPublished (ACTIVE), sans
      // que le AnnouncementDetailLoaded du reload ne suive (ex. erreur réseau
      // transitoire sur AnnouncementDetailRequested). Cet état déclenche aussi
      // la navigation plein écran vers DonySuccessScreen — on laisse
      // l'animation de route se terminer avant d'inspecter l'écran sous-jacent.
      controller.add(AnnouncementPublished(published));
      await tester.pumpAndSettle();

      expect(find.textContaining('brouillon'), findsNothing);
      expect(find.text('Publier'), findsNothing);
      expect(find.textContaining('BROUILLON'), findsNothing);
    },
  );

  testWidgets(
    'AnnouncementPublished affiche un DonySuccessScreen plein écran ; '
    'tap sur Continuer revient au détail déjà rafraîchi',
    (tester) async {
      final draft = _makeAnnouncement(status: 'DRAFT');
      final published = _makeAnnouncement();

      when(() => annBloc.state).thenReturn(AnnouncementDetailLoaded(draft));
      final controller = StreamController<AnnouncementState>();
      whenListen(
        annBloc,
        controller.stream,
        initialState: AnnouncementDetailLoaded(draft),
      );
      addTearDown(controller.close);

      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
        initial: draft,
      );
      await tester.pumpAndSettle();

      controller.add(AnnouncementPublished(published));
      await tester.pumpAndSettle();

      expect(find.byType(DonySuccessScreen), findsOneWidget);
      expect(find.text('Trajet publié !'), findsOneWidget);

      verify(
        () => annBloc.add(
          any(
            that: predicate<AnnouncementEvent>(
              (e) => e is AnnouncementDetailRequested && e.id == 'ann-trip-001',
              'AnnouncementDetailRequested(ann-trip-001)',
            ),
          ),
        ),
      ).called(1);

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.byType(DonySuccessScreen), findsNothing);
      expect(find.byType(TripOwnerDetailScreen), findsOneWidget);
    },
  );

  group('statut légal du voyageur à la publication d\'un brouillon', () {
    late _MockTravelerStatusRepository statusRepo;
    late _MockGpProRepository gpRepo;

    /// Ce que l'écran de blocage relit : limite de 4 trajets atteinte.
    void stubEligibility(PublishingReason reason) {
      when(() => statusRepo.checkEligibility()).thenAnswer(
        (_) async => (
          eligibility: PublishingEligibility(
            allowed: false,
            reason: reason,
            limit: 4,
            used: 4,
            resetsOn: DateTime(2026, 12),
          ),
          failureCode: null,
        ),
      );
    }

    setUp(() {
      gpRepo = _MockGpProRepository();
      when(
        () => gpRepo.fetchStatus(),
      ).thenAnswer((_) async => const GpProStatus(state: GpProState.none));
      getIt.registerSingleton<GpProRepository>(gpRepo);
      statusRepo = _MockTravelerStatusRepository();
      when(() => statusRepo.declareIndividual()).thenAnswer(
        (_) async => TravelerStatusDeclaration(
          status: TravelerStatus.individual,
          declaredAt: DateTime.utc(2026, 11),
        ),
      );
      stubEligibility(PublishingReason.statusRequired);
      getIt.registerSingleton<TravelerStatusRepository>(statusRepo);
      getIt.registerFactory<TravelerStatusCubit>(
        () => TravelerStatusCubit(statusRepo, analytics),
      );
      when(
        () => authBloc.state,
      ).thenReturn(const AuthAuthenticated(_ownerUndeclared));
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(_ownerUndeclared),
      );
    });

    tearDown(() {
      if (getIt.isRegistered<TravelerStatusCubit>()) {
        getIt.unregister<TravelerStatusCubit>();
      }
      if (getIt.isRegistered<TravelerStatusRepository>()) {
        getIt.unregister<TravelerStatusRepository>();
      }
      if (getIt.isRegistered<GpProRepository>()) {
        getIt.unregister<GpProRepository>();
      }
    });

    GoRouter? router;

    Future<StreamController<AnnouncementState>> pumpDraft(
      WidgetTester tester,
    ) async {
      final draft = _makeAnnouncement(status: 'DRAFT');
      when(() => annBloc.state).thenReturn(AnnouncementDetailLoaded(draft));
      final controller = StreamController<AnnouncementState>();
      whenListen(
        annBloc,
        controller.stream,
        initialState: AnnouncementDetailLoaded(draft),
      );
      addTearDown(controller.close);
      router = await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
        initial: draft,
      );
      await tester.pumpAndSettle();
      return controller;
    }

    void verifyPublishDispatched(int times) => verify(
      () => annBloc.add(
        any(
          that: predicate<AnnouncementEvent>(
            (e) => e is AnnouncementPublishRequested && e.id == 'ann-trip-001',
            'AnnouncementPublishRequested',
          ),
        ),
      ),
    ).called(times);

    testWidgets(
      'sans statut : « Publier » ouvre la question, rien n\'est publié '
      'tant qu\'elle est ouverte',
      (tester) async {
        await pumpDraft(tester);

        await tester.tap(_inFooter(find.text('Publier')));
        await tester.pumpAndSettle();

        expect(find.text('Vous voyagez en tant que ?'), findsOneWidget);
        verifyNever(
          () => annBloc.add(any(that: isA<AnnouncementPublishRequested>())),
        );
      },
    );

    testWidgets('badge GP Pro déjà accordé : « Publier » ne pose aucune '
        'question', (tester) async {
      const gpPro = UserModel(
        id: _ownerId,
        roles: [],
        kycStatus: 'VERIFIED',
        status: 'ACTIVE',
        gpPro: true,
      );
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(gpPro));
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(gpPro),
      );
      await pumpDraft(tester);

      await tester.tap(_inFooter(find.text('Publier')));
      await tester.pumpAndSettle();

      expect(find.text('Vous voyagez en tant que ?'), findsNothing);
      verifyPublishDispatched(1);
    });

    testWidgets('écran quitté pendant la question : rien n\'est publié, '
        'aucune exception', (tester) async {
      await pumpDraft(tester);

      await tester.tap(_inFooter(find.text('Publier')));
      await tester.pumpAndSettle();
      expect(find.text('Vous voyagez en tant que ?'), findsOneWidget);

      // L'écran du brouillon est remplacé pendant que la feuille est ouverte :
      // la navigation ferme la feuille. Aucune exception. (La feuille se
      // referme avant que l'écran soit démonté : c'est le bloc fermé, testé
      // ci-dessous, qui sépare le cas fautif du cas sain.)
      router!.go('/kyc/status');
      await tester.pumpAndSettle();

      expect(find.byType(TripOwnerDetailScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bloc fermé pendant la question : rien n\'est publié', (
      tester,
    ) async {
      await pumpDraft(tester);

      await tester.tap(_inFooter(find.text('Publier')));
      await tester.pumpAndSettle();
      when(() => annBloc.isClosed).thenReturn(true);
      await tester.tap(find.widgetWithText(DonyButton, 'Plus tard'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      verifyNever(
        () => annBloc.add(any(that: isA<AnnouncementPublishRequested>())),
      );
    });

    testWidgets('« Plus tard » : la publication continue', (tester) async {
      await pumpDraft(tester);

      await tester.tap(_inFooter(find.text('Publier')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DonyButton, 'Plus tard'));
      await tester.pumpAndSettle();

      expect(find.text('Vous voyagez en tant que ?'), findsNothing);
      verifyPublishDispatched(1);
    });

    testWidgets('« Particulier » : la publication continue et le profil '
        'est rechargé', (tester) async {
      await pumpDraft(tester);

      await tester.tap(_inFooter(find.text('Publier')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Particulier'));
      await tester.pumpAndSettle();

      verifyPublishDispatched(1);
      verify(
        () => authBloc.add(any(that: isA<AuthProfileRefreshRequested>())),
      ).called(1);
    });

    testWidgets('demande GP Pro ouverte : « Publier » ne pose pas la question, '
        'la publication part', (tester) async {
      when(() => gpRepo.fetchStatus()).thenAnswer(
        (_) async => const GpProStatus(state: GpProState.awaitingKyc),
      );
      await pumpDraft(tester);

      await tester.tap(_inFooter(find.text('Publier')));
      await tester.pumpAndSettle();

      expect(find.text('Vous voyagez en tant que ?'), findsNothing);
      verifyPublishDispatched(1);
    });

    testWidgets('lecture de la demande GP Pro en échec : la question est '
        'posée', (tester) async {
      when(
        () => gpRepo.fetchStatus(),
      ).thenThrow(const GpProException('network'));
      await pumpDraft(tester);

      await tester.tap(_inFooter(find.text('Publier')));
      await tester.pumpAndSettle();

      expect(find.text('Vous voyagez en tant que ?'), findsOneWidget);
    });

    testWidgets('« GP Pro » puis formulaire quitté sans envoyer : rien n\'est '
        'publié, aucun message', (tester) async {
      await pumpDraft(tester);

      await tester.tap(_inFooter(find.text('Publier')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GP Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('formulaire GP Pro'));
      await tester.pumpAndSettle();

      verifyNever(
        () => annBloc.add(any(that: isA<AnnouncementPublishRequested>())),
      );
      expect(find.byType(TripOwnerDetailScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« GP Pro » puis demande envoyée : la publication part', (
      tester,
    ) async {
      await pumpDraft(tester);

      await tester.tap(_inFooter(find.text('Publier')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GP Pro'));
      await tester.pumpAndSettle();
      // La demande part depuis le formulaire.
      when(
        () => gpRepo.fetchStatus(),
      ).thenAnswer((_) async => const GpProStatus(state: GpProState.pending));
      await tester.tap(find.text('formulaire GP Pro'));
      await tester.pumpAndSettle();

      verifyPublishDispatched(1);
    });

    group('le back refuse (403)', () {
      Future<StreamController<AnnouncementState>> pumpOwner(
        WidgetTester tester,
      ) async {
        // Statut déjà connu de l'app (profil périmé) : la publication part, le
        // back refuse, l'écran de blocage s'ouvre.
        when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
        whenListen(
          authBloc,
          const Stream<AuthState>.empty(),
          initialState: const AuthAuthenticated(_owner),
        );
        return pumpDraft(tester);
      }

      AnnouncementPublishingBlocked blocked(
        String code,
        PublishingReason reason,
      ) => AnnouncementPublishingBlocked(ForbiddenException('x', code), reason);

      testWidgets('traveler-status-required : écran de blocage avec les deux '
          'choix, sans « Plus tard »', (tester) async {
        final controller = await pumpOwner(tester);
        addTearDown(controller.close);

        await tester.tap(_inFooter(find.text('Publier')));
        await tester.pumpAndSettle();
        verifyPublishDispatched(1);
        expect(find.text('Vous voyagez en tant que ?'), findsNothing);

        controller.add(
          blocked('traveler-status-required', PublishingReason.statusRequired),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Limite de 4 trajets atteinte ce mois-ci'),
          findsOneWidget,
        );
        expect(find.widgetWithText(DonyButton, 'Plus tard'), findsNothing);
        expect(find.text('Particulier'), findsOneWidget);
        expect(find.text('GP Pro'), findsOneWidget);
      });

      testWidgets('monthly-limit-reached : « Fermer » ne republie pas', (
        tester,
      ) async {
        stubEligibility(PublishingReason.limitReached);
        final controller = await pumpOwner(tester);
        addTearDown(controller.close);
        await tester.tap(_inFooter(find.text('Publier')));
        await tester.pumpAndSettle();

        controller.add(
          blocked('monthly-limit-reached', PublishingReason.limitReached),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Vous ne pouvez plus créer de trajet ce mois-ci'),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(DonyButton, 'Fermer'));
        await tester.pumpAndSettle();

        expect(find.byType(TripOwnerDetailScreen), findsOneWidget);
        verifyPublishDispatched(1);
      });

      testWidgets('gp-pro-pending, demande validée au retour : la publication '
          'reprend', (tester) async {
        stubEligibility(PublishingReason.gpProPending);
        final controller = await pumpOwner(tester);
        addTearDown(controller.close);
        await tester.tap(_inFooter(find.text('Publier')));
        await tester.pumpAndSettle();
        verifyPublishDispatched(1);

        controller.add(
          blocked('gp-pro-pending', PublishingReason.gpProPending),
        );
        await tester.pumpAndSettle();
        expect(
          find.text("Votre demande GP Pro est en cours d'examen"),
          findsOneWidget,
        );

        when(() => statusRepo.checkEligibility()).thenAnswer(
          (_) async =>
              (eligibility: PublishingEligibility.ok, failureCode: null),
        );
        await tester.tap(find.widgetWithText(DonyButton, 'Voir ma demande'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('formulaire GP Pro'));
        await tester.pumpAndSettle();

        // Une seconde publication après la validation (mocktail ne recompte
        // pas l'appel déjà vérifié plus haut).
        verifyPublishDispatched(1);
      });

      testWidgets('écran quitté pendant l\'écran de blocage : aucune '
          'publication, aucune exception', (tester) async {
        final controller = await pumpOwner(tester);
        addTearDown(controller.close);

        controller.add(
          blocked('traveler-status-required', PublishingReason.statusRequired),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Limite de 4 trajets atteinte ce mois-ci'),
          findsOneWidget,
        );

        router!.go('/kyc/status');
        await tester.pumpAndSettle();

        expect(find.byType(TripOwnerDetailScreen), findsNothing);
        expect(tester.takeException(), isNull);
        verifyNever(
          () => annBloc.add(any(that: isA<AnnouncementPublishRequested>())),
        );
      });

      testWidgets('bloc fermé pendant l\'écran de blocage, demande validée : '
          'aucune publication', (tester) async {
        stubEligibility(PublishingReason.gpProPending);
        final controller = await pumpOwner(tester);
        addTearDown(controller.close);

        controller.add(
          blocked('gp-pro-pending', PublishingReason.gpProPending),
        );
        await tester.pumpAndSettle();
        when(() => annBloc.isClosed).thenReturn(true);
        when(() => statusRepo.checkEligibility()).thenAnswer(
          (_) async =>
              (eligibility: PublishingEligibility.ok, failureCode: null),
        );
        await tester.tap(find.widgetWithText(DonyButton, 'Voir ma demande'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('formulaire GP Pro'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        verifyNever(
          () => annBloc.add(any(that: isA<AnnouncementPublishRequested>())),
        );
      });
    });
  });
}

/// [f] dans le pied collant de l'écran.
Finder _inFooter(Finder f) => find.descendant(
  of: find.byKey(const Key('trip-owner-sticky-bar')),
  matching: f,
);
