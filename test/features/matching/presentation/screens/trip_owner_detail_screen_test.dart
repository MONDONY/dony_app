import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_app_bar.dart';
import 'package:dony/core/design/widgets/dony_feedback_button.dart';
import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/bloc/trip_mobile_money_networks_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/screens/trip_owner_detail_screen.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_audience_line.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_consent_cubit.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/stripe_account_test_doubles.dart';
import '../../../../helpers/trip_answer_blocs.dart';

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

/// Réponse directe aux demandes (`TripBidAnswerScope`) : blocs propres au
/// scope, fournis par getIt dans l'app.
class _MockBidAcceptanceBloc
    extends MockBloc<ace.BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

class _MockTrackingConsent extends Mock implements TrackingConsentCubit {}

class _FakeContext extends Fake implements BuildContext {}

/// « Je pars » : l'écran fournit son cubit (getIt) ; ces tests ne partent pas.
class _MockTripDepartCubit extends MockCubit<TripDepartState>
    implements TripDepartCubit {}

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

// ── Fixture builder ───────────────────────────────────────────────────────────

const _ownerId = 'trav-001';

const _owner = UserModel(
  id: _ownerId,
  roles: [],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

AnnouncementModel _makeAnnouncement({
  String status = 'ACTIVE',
  String? arrivalInstructions,
  Set<BidPaymentMethod> acceptedPaymentMethods = const {
    BidPaymentMethod.stripe,
  },
}) => AnnouncementModel(
  arrivalInstructions: arrivalInstructions,
  acceptedPaymentMethods: acceptedPaymentMethods,
  id: 'ann-trip-001',
  travelerId: _ownerId,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 7),
  availableKg: 10,
  totalKg: 23,
  pricePerKg: 8,
  status: status,
  bidsCount: 0,
  createdAt: DateTime(2026, 6),
  updatedAt: DateTime(2026, 6),
);

BidModel _makeBid({
  required String status,
  String id = 'bid-001',
  String? recipientPhone,
}) => BidModel(
  id: id,
  recipientName: 'Awa',
  recipientPhone: recipientPhone,
  announcementId: 'ann-trip-001',
  senderId: 'sender-001',
  status: status,
  createdAt: DateTime(2026, 6),
  updatedAt: DateTime(2026, 6),
);

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester, {
  required _MockAnnouncementBloc annBloc,
  required _MockBidBloc bidBloc,
  required _MockCancellationBloc cancelBloc,
  required _MockAuthBloc authBloc,
  StripeAccountState? stripeState,
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
              value: stripeState == null
                  ? stubStripeAccountBloc()
                  : stubStripeAccountBloc(state: stripeState),
            ),
          ],
          child: const TripOwnerDetailScreen(announcementId: 'ann-trip-001'),
        ),
      ),
      // Édition du trajet : rend « modifié » pour que l'écran relise le
      // détail au retour.
      GoRoute(
        path: '/trips/create',
        builder: (ctx, _) => Scaffold(
          body: TextButton(
            onPressed: () => ctx.pop(true),
            child: const Text('TRIP_EDIT_SAVE'),
          ),
        ),
      ),
      // Destinations poussées après les snackbars d'erreur typée (KYC,
      // limite PRO) — de simples écrans muets, jamais vérifiés par ces
      // tests, juste nécessaires pour que le `context.push` ne lève pas de
      // GoException faute de route déclarée.
      GoRoute(
        path: '/kyc/status',
        builder: (ctx, _) => const Scaffold(body: Text('KYC_STATUS')),
      ),
      GoRoute(
        path: '/profile/upgrade-to-pro',
        builder: (ctx, _) => const Scaffold(body: Text('UPGRADE_TO_PRO')),
      ),
      // Demandes à traiter du trajet (carte Demandes, tuile « À traiter »,
      // pied) : `back` revient à l'écran.
      GoRoute(
        path: '/demandes',
        builder: (ctx, state) => Scaffold(
          body: TextButton(
            onPressed: () => ctx.pop(),
            child: Text('DEMANDES:${state.uri.query}'),
          ),
        ),
      ),
      // Fiche d'un colis et liste des colis du trajet (sheets « Activité du
      // trajet ») : `back` revient à l'écran.
      GoRoute(
        path: '/bids/:bidId',
        builder: (ctx, state) => Scaffold(
          body: TextButton(
            onPressed: () => ctx.pop(),
            child: Text('BID:${state.pathParameters['bidId']}'),
          ),
        ),
      ),
      GoRoute(
        path: '/announcements/:id/bids',
        builder: (ctx, state) => Scaffold(
          body: TextButton(
            onPressed: () => ctx.pop(),
            child: Text('PARCELS:${state.pathParameters['id']}'),
          ),
        ),
      ),
      // Affiche partageable : même destination pour la tuile « Affiche » et
      // l'icône de partage de l'en-tête.
      GoRoute(
        path: '/announcements/:id/affiche',
        builder: (ctx, state) => Scaffold(
          appBar: AppBar(),
          body: Text('AFFICHE:${state.pathParameters['id']}'),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

// ── Pump helper (pile navigable) ──────────────────────────────────────────────
//
// Reproduit la topologie de `app.dart` : les blocs globaux (Auth, Bid) sont
// AU-DESSUS de `MaterialApp.router`, si bien qu'une sheet ouverte sur le
// navigateur racine peut les lire. Nécessaire pour tester la redirection
// visiteur → sheet expéditeur, qui quitte l'écran (pop) avant d'ouvrir la sheet.
Future<GoRouter> _pumpRouted(
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
        builder: (ctx, _) => const Scaffold(body: Text('HOST')),
      ),
      GoRoute(
        path: '/detail',
        builder: (ctx, _) => TripOwnerDetailScreen(
          announcementId: 'ann-trip-001',
          initial: initial,
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AnnouncementBloc>.value(value: annBloc),
        BlocProvider<BidBloc>.value(value: bidBloc),
        BlocProvider<CancellationBloc>.value(value: cancelBloc),
        BlocProvider<TripAudienceCubit>.value(value: _hiddenAudience()),
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<StripeAccountBloc>.value(value: stubStripeAccountBloc()),
      ],
      child: MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    ),
  );
  unawaited(router.push('/detail'));
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
  late _MockBidBloc answerBids;
  late StreamController<BidState> answerStates;
  late List<BidEvent> answerEvents;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(BidListRequested('fallback'));
    registerFallbackValue(_FakeContext());
  });

  setUp(() {
    annBloc = _MockAnnouncementBloc();
    bidBloc = _MockBidBloc();
    cancelBloc = _MockCancellationBloc();
    authBloc = _MockAuthBloc();
    analytics = _MockAnalyticsService();

    // Par défaut, non-propriétaire (aucun utilisateur authentifié résolu) —
    // seuls les tests dédiés au bouton "Arrivé à destination" surchargent cet
    // état pour simuler le propriétaire du trajet.
    when(() => authBloc.state).thenReturn(const AuthInitial());
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthInitial(),
    );

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

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
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

    // Scope de réponse du propriétaire : son BidBloc (piloté par
    // `answerStates`) et son BidAcceptanceBloc, jamais ceux de la route.
    answerStates = StreamController<BidState>.broadcast();
    answerEvents = [];
    answerBids = _MockBidBloc();
    whenListen(answerBids, answerStates.stream, initialState: BidInitial());
    when(() => answerBids.add(any())).thenAnswer(
      (i) => answerEvents.add(i.positionalArguments.first as BidEvent),
    );
    final acceptance = _MockBidAcceptanceBloc();
    whenListen(
      acceptance,
      const Stream<acs.BidAcceptanceState>.empty(),
      initialState: acs.BidAcceptanceInitial(),
    );
    unregisterTripAnswerBlocs();
    getIt
      ..registerFactory<BidBloc>(() => answerBids)
      ..registerFactory<BidAcceptanceBloc>(() => acceptance);
  });

  tearDown(() {
    unawaited(answerStates.close());
    unregisterTripAnswerBlocs();
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

  testWidgets('affiche l\'AppBar Trajet, le bouton bug et le corridor', (
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

    expect(find.byType(DonyAppBar), findsOneWidget);
    expect(find.text('Trajet'), findsOneWidget);
    expect(find.byType(DonyFeedbackButton), findsOneWidget);
    // Corridor rendu par la tête du trajet (TripOwnerHeader).
    expect(find.bySemanticsLabel('Paris → Dakar'), findsOneWidget);
  });

  testWidgets(
    'affiche un skeleton quand le détail charge sans annonce initiale',
    (tester) async {
      when(() => annBloc.state).thenReturn(AnnouncementLoading());
      whenListen(
        annBloc,
        Stream<AnnouncementState>.value(AnnouncementLoading()),
        initialState: AnnouncementLoading(),
      );

      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pump();

      expect(find.byType(DonyDetailSkeleton), findsOneWidget);
    },
  );

  testWidgets('shows arrival button when all active bids are IN_TRANSIT', (
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

    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthAuthenticated(_owner),
    );

    final bids = [_makeBid(status: 'IN_TRANSIT')];
    when(() => bidBloc.state).thenReturn(BidListLoaded(bids));
    whenListen(
      bidBloc,
      Stream<BidState>.value(BidListLoaded(bids)),
      initialState: BidListLoaded(bids),
    );

    await _pump(
      tester,
      annBloc: annBloc,
      bidBloc: bidBloc,
      cancelBloc: cancelBloc,
      authBloc: authBloc,
    );
    await tester.pumpAndSettle();

    expect(find.text('Arrivé à destination'), findsOneWidget);
  });

  group('Prévenir les destinataires (lot 3B)', () {
    void ownerWithBids(List<BidModel> bids, {AnnouncementModel? announcement}) {
      final a = announcement ?? _makeAnnouncement();
      when(() => annBloc.state).thenReturn(AnnouncementDetailLoaded(a));
      whenListen(
        annBloc,
        Stream<AnnouncementState>.value(AnnouncementDetailLoaded(a)),
        initialState: AnnouncementDetailLoaded(a),
      );
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(_owner),
      );
      when(() => bidBloc.state).thenReturn(BidListLoaded(bids));
      whenListen(
        bidBloc,
        Stream<BidState>.value(BidListLoaded(bids)),
        initialState: BidListLoaded(bids),
      );
    }

    // Cible validée : « Prévenir les destinataires » est le bouton du pied
    // après l'arrivée seulement ; avant, le pied propose « Arrivé à
    // destination ».
    testWidgets('colis en route : « Arrivé à destination », pas « Prévenir »', (
      tester,
    ) async {
      ownerWithBids([
        _makeBid(status: 'IN_TRANSIT', recipientPhone: '+221700000000'),
      ]);
      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trip-footer-markArrived')), findsOneWidget);
      expect(
        find.byKey(const Key('trip-footer-notifyRecipients')),
        findsNothing,
      );
    });

    testWidgets('arrivée marquée : bouton du pied, ouvre la feuille', (
      tester,
    ) async {
      ownerWithBids([
        _makeBid(status: 'ARRIVED', recipientPhone: '+221700000000'),
        _makeBid(status: 'ACCEPTED', id: 'bid-002'),
      ]);
      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();

      final button = find.text('Prévenir les destinataires (1)');
      expect(button, findsOneWidget);
      // Pied collant, hors du défilement.
      expect(
        find.descendant(
          of: find.byKey(const Key('trip-owner-sticky-bar')),
          matching: button,
        ),
        findsOneWidget,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Prévenir les destinataires'), findsOneWidget);
      expect(find.byKey(const Key('notify-recipient-bid-001')), findsOneWidget);
      expect(find.byKey(const Key('notify-recipient-bid-002')), findsNothing);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.recipientsNotifyOpened,
          properties: {'count': 1, 'source': 'manual'},
        ),
      ).called(1);
    });

    testWidgets('aucun colis remis, en transit ou arrivé : pas de bouton', (
      tester,
    ) async {
      ownerWithBids([_makeBid(status: 'ACCEPTED')]);
      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('trip-footer-notifyRecipients')),
        findsNothing,
      );
    });

    testWidgets('visiteur non propriétaire : pas de bouton', (tester) async {
      ownerWithBids([_makeBid(status: 'ARRIVED')]);
      when(() => authBloc.state).thenReturn(const AuthInitial());
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthInitial(),
      );
      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('trip-footer-notifyRecipients')),
        findsNothing,
      );
    });

    Future<(StreamController<AnnouncementState>, StreamController<BidState>)>
    pumpArrival(WidgetTester tester) async {
      final a = _makeAnnouncement();
      final annCtrl = StreamController<AnnouncementState>.broadcast();
      final bidCtrl = StreamController<BidState>.broadcast();
      addTearDown(annCtrl.close);
      addTearDown(bidCtrl.close);
      final before = [_makeBid(status: 'IN_TRANSIT')];
      when(() => annBloc.state).thenReturn(AnnouncementDetailLoaded(a));
      whenListen(
        annBloc,
        annCtrl.stream,
        initialState: AnnouncementDetailLoaded(a),
      );
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(_owner),
      );
      when(() => bidBloc.state).thenReturn(BidListLoaded(before));
      whenListen(bidBloc, bidCtrl.stream, initialState: BidListLoaded(before));
      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();
      return (annCtrl, bidCtrl);
    }

    testWidgets('« Marquer arrivé » réussi : la feuille s’ouvre seule', (
      tester,
    ) async {
      final (annCtrl, bidCtrl) = await pumpArrival(tester);
      final arrived = _makeAnnouncement(
        status: 'ARRIVED',
        arrivalInstructions: 'Gare de Pikine',
      );

      annCtrl.add(AnnouncementTripArrived(arrived));
      await tester.pump();
      verify(
        () => bidBloc.add(any(that: isA<BidListRequested>())),
      ).called(greaterThanOrEqualTo(1));
      expect(find.text('Prévenir les destinataires'), findsNothing);

      bidCtrl.add(BidLoading());
      await tester.pump();
      bidCtrl.add(
        BidListLoaded([
          _makeBid(status: 'ARRIVED', recipientPhone: '+221700000000'),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Prévenir les destinataires'), findsOneWidget);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.recipientsNotifyOpened,
          properties: {'count': 1, 'source': 'after_arrival'},
        ),
      ).called(1);

      // Un rechargement ultérieur ne rouvre pas la feuille.
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      bidCtrl.add(BidListLoaded([_makeBid(status: 'ARRIVED')]));
      await tester.pumpAndSettle();
      expect(find.text('Prévenir les destinataires'), findsNothing);
    });

    testWidgets('rechargement en échec : pas d’ouverture automatique', (
      tester,
    ) async {
      final (annCtrl, bidCtrl) = await pumpArrival(tester);
      annCtrl.add(
        AnnouncementTripArrived(_makeAnnouncement(status: 'ARRIVED')),
      );
      await tester.pump();
      bidCtrl.add(BidError(const NetworkException('offline')));
      await tester.pump();
      bidCtrl.add(BidListLoaded([_makeBid(status: 'ARRIVED')]));
      await tester.pumpAndSettle();
      expect(find.text('Prévenir les destinataires'), findsNothing);
    });
  });

  Future<void> pumpOwnerWith(
    WidgetTester tester, {
    required AnnouncementModel announcement,
    required AuthState auth,
    StripeAccountState? stripeState,
    List<BidModel>? bids,
  }) async {
    when(
      () => annBloc.state,
    ).thenReturn(AnnouncementDetailLoaded(announcement));
    whenListen(
      annBloc,
      Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
      initialState: AnnouncementDetailLoaded(announcement),
    );
    when(() => authBloc.state).thenReturn(auth);
    whenListen(authBloc, const Stream<AuthState>.empty(), initialState: auth);
    final loaded = bids ?? [_makeBid(status: 'ARRIVED')];
    when(() => bidBloc.state).thenReturn(BidListLoaded(loaded));
    whenListen(
      bidBloc,
      Stream<BidState>.value(BidListLoaded(loaded)),
      initialState: BidListLoaded(loaded),
    );
    await _pump(
      tester,
      annBloc: annBloc,
      bidBloc: bidBloc,
      cancelBloc: cancelBloc,
      authBloc: authBloc,
      stripeState: stripeState,
    );
    await tester.pumpAndSettle();
  }

  // Sentry FLUTTER-DH : trajet publié en espèces avant l'activation de Stripe.
  // Seulement des demandes : le back accepte encore la modification.
  testWidgets(
    'propriétaire, Stripe activé, trajet en espèces : « Ajouter la carte » '
    'ouvre l\'édition puis relit le détail',
    (tester) async {
      await pumpOwnerWith(
        tester,
        announcement: _makeAnnouncement(
          acceptedPaymentMethods: const {BidPaymentMethod.cash},
        ),
        auth: const AuthAuthenticated(_owner),
        stripeState: const StripeAccountReady(
          ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
        ),
        bids: [_makeBid(status: 'PENDING')],
      );
      clearInteractions(annBloc);

      // L'encart est devenu la tuile « À traiter », qui ouvre son sheet.
      final tile = find.byKey(const Key('trip_owner-todo-card'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      final cta = find.byKey(const Key('enable-card-on-trip-cta'));
      expect(cta, findsOneWidget);
      await tester.tap(cta);
      await tester.pumpAndSettle();
      await tester.tap(find.text('TRIP_EDIT_SAVE'));
      await tester.pumpAndSettle();

      registerFallbackValue(AnnouncementDetailRequested('fallback'));
      final reloads = verify(
        () => annBloc.add(captureAny()),
      ).captured.whereType<AnnouncementDetailRequested>();
      expect(reloads.single.id, 'ann-trip-001');
    },
  );

  // Un colis accepté, remis ou arrivé : le back répond 409
  // `modification-impossible` à toute modification, la tuile mènerait à un
  // refus certain (relecture finale, n° 1).
  for (final status in const ['ACCEPTED', 'ARRIVED']) {
    testWidgets('propriétaire, trajet en espèces avec un colis $status : '
        'pas de tuile « Ajouter la carte »', (tester) async {
      await pumpOwnerWith(
        tester,
        announcement: _makeAnnouncement(
          acceptedPaymentMethods: const {BidPaymentMethod.cash},
        ),
        auth: const AuthAuthenticated(_owner),
        stripeState: const StripeAccountReady(
          ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
        ),
        bids: [_makeBid(status: status)],
      );
      expect(find.byKey(const Key('trip_owner-todo-card')), findsNothing);
      expect(find.byKey(const Key('enable-card-on-trip-cta')), findsNothing);
    });
  }

  // Le voyageur ne relisait son texte que dans la feuille d'édition, qui
  // disparaît avec le dernier colis actif.
  testWidgets('proprietaire : encart des instructions de retrait', (
    tester,
  ) async {
    await pumpOwnerWith(
      tester,
      announcement: _makeAnnouncement(arrivalInstructions: 'Gare routière'),
      auth: const AuthAuthenticated(_owner),
    );

    // L'encart a quitté le corps pour la tuile « Arrivée » (une seule
    // carte à l'écran, sinon deux clés `arrival-instructions-card`).
    expect(find.byKey(const Key('arrival-instructions-card')), findsNothing);
    final tile = find.byKey(const Key('trip-tile-arrival'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('arrival-instructions-card')), findsOneWidget);
    expect(find.text('Gare routière'), findsOneWidget);
  });

  testWidgets('proprietaire : la ligne d’audience du trajet est montée', (
    tester,
  ) async {
    await pumpOwnerWith(
      tester,
      announcement: _makeAnnouncement(),
      auth: const AuthAuthenticated(_owner),
    );

    expect(find.byType(TripAudienceLine), findsOneWidget);
  });

  testWidgets('proprietaire sans instructions : aucun encart', (tester) async {
    await pumpOwnerWith(
      tester,
      announcement: _makeAnnouncement(),
      auth: const AuthAuthenticated(_owner),
    );

    expect(find.byKey(const Key('arrival-instructions-card')), findsNothing);
  });

  // Scan Transit facultatif : un colis récupéré suffit à marquer l'arrivée.
  testWidgets(
    'shows arrival button when a parcel is picked up without transit',
    (tester) async {
      final announcement = _makeAnnouncement();
      when(
        () => annBloc.state,
      ).thenReturn(AnnouncementDetailLoaded(announcement));
      whenListen(
        annBloc,
        Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
        initialState: AnnouncementDetailLoaded(announcement),
      );

      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(_owner),
      );

      final bids = [_makeBid(status: 'HANDED_OVER')];
      when(() => bidBloc.state).thenReturn(BidListLoaded(bids));
      whenListen(
        bidBloc,
        Stream<BidState>.value(BidListLoaded(bids)),
        initialState: BidListLoaded(bids),
      );

      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();

      expect(find.text('Arrivé à destination'), findsOneWidget);
    },
  );

  testWidgets(
    'reloads bids after AnnouncementTripArrived so the CTA can switch mode',
    (tester) async {
      final announcement = _makeAnnouncement();
      when(
        () => annBloc.state,
      ).thenReturn(AnnouncementDetailLoaded(announcement));
      whenListen(
        annBloc,
        Stream<AnnouncementState>.fromIterable([
          AnnouncementDetailLoaded(announcement),
          AnnouncementTripArrived(announcement),
        ]),
        initialState: AnnouncementDetailLoaded(announcement),
      );

      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(_owner),
      );

      final bids = [_makeBid(status: 'IN_TRANSIT')];
      when(() => bidBloc.state).thenReturn(BidListLoaded(bids));
      whenListen(
        bidBloc,
        Stream<BidState>.value(BidListLoaded(bids)),
        initialState: BidListLoaded(bids),
      );

      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();

      // Régression I9(a) : sans le refresh, AnnouncementTripArrived ne
      // déclenche aucun BidListRequested, le bloc bids reste figé sur
      // IN_TRANSIT et le pied réaffiche « Arrivé à destination » au lieu de
      // passer à « Prévenir les destinataires ».
      verify(
        () => bidBloc.add(
          any(
            that: isA<BidListRequested>().having(
              (e) => e.announcementId,
              'announcementId',
              'ann-trip-001',
            ),
          ),
        ),
      ).called(1);
    },
  );

  // ── Régression ARRIVED : le CTA doit survivre au marquage ────────────────────
  // Avant le fix, ARRIVED n'était pas un statut « actif » : la liste des bids
  // actifs devenait vide et le bouton disparaissait définitivement, rendant les
  // instructions de retrait non éditables.
  testWidgets(
    'tous les colis ARRIVED → « Modifier les instructions » dans la tuile '
    '« Arrivée », plus « Arrivé à destination »',
    (tester) async {
      final announcement = _makeAnnouncement();
      when(
        () => annBloc.state,
      ).thenReturn(AnnouncementDetailLoaded(announcement));
      whenListen(
        annBloc,
        Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
        initialState: AnnouncementDetailLoaded(announcement),
      );

      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(_owner),
      );

      final bids = [_makeBid(status: 'ARRIVED')];
      when(() => bidBloc.state).thenReturn(BidListLoaded(bids));
      whenListen(
        bidBloc,
        Stream<BidState>.value(BidListLoaded(bids)),
        initialState: BidListLoaded(bids),
      );

      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();

      expect(find.text('Arrivé à destination'), findsNothing);
      final tile = find.byKey(const Key('trip-tile-arrival'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('trip-tile-arrival-edit-button')),
        findsOneWidget,
      );
      expect(find.text('Modifier les instructions'), findsOneWidget);
    },
  );

  // ── Visiteur non propriétaire (deep link d'affiche partagée) ───────────────
  // Un expéditeur qui ouvre le lien d'un trajet d'un AUTRE voyageur ne doit pas
  // voir l'écran propriétaire (compteurs de colis, nudge paiements par carte) :
  // il doit retrouver la vue expéditeur du feed, avec le CTA « Faire une
  // demande ».
  testWidgets(
    'visiteur authentifié non propriétaire → sheet expéditeur, écran quitté',
    (tester) async {
      final announcement = _makeAnnouncement();
      when(
        () => annBloc.state,
      ).thenReturn(AnnouncementDetailLoaded(announcement));
      whenListen(
        annBloc,
        Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
        initialState: AnnouncementDetailLoaded(announcement),
      );

      const visitor = UserModel(
        id: 'sender-042',
        roles: [],
        kycStatus: 'VERIFIED',
        status: 'ACTIVE',
      );
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(visitor));
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(visitor),
      );

      await _pumpRouted(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();

      expect(find.byType(TripOwnerDetailScreen), findsNothing);
      expect(find.text('Faire une demande'), findsOneWidget);
    },
  );

  // Réseaux mobile money du trajet : relus au détail seulement quand la feuille
  // reçoit le modèle de la liste (`extra`), jamais pour celui du détail.
  group('visiteur : relecture des réseaux mobile money', () {
    late _MockAnnouncementRepository repository;

    const visitor = UserModel(
      id: 'sender-042',
      roles: [],
      kycStatus: 'VERIFIED',
      status: 'ACTIVE',
    );

    setUp(() {
      repository = _MockAnnouncementRepository();
      when(
        () => repository.getAnnouncementDetail(any()),
      ).thenAnswer((_) async => _makeAnnouncement());
      getIt.registerFactory<TripMobileMoneyNetworksCubit>(
        () => TripMobileMoneyNetworksCubit(repository),
      );
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(visitor));
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(visitor),
      );
    });

    tearDown(() => getIt.unregister<TripMobileMoneyNetworksCubit>());

    final mobileMoneyTrip = _makeAnnouncement(
      acceptedPaymentMethods: const {
        BidPaymentMethod.mobileMoney,
        BidPaymentMethod.stripe,
      },
    );

    testWidgets('modèle de la liste (extra) : fromDetail faux, détail relu', (
      tester,
    ) async {
      when(() => annBloc.state).thenReturn(AnnouncementLoading());
      whenListen(
        annBloc,
        const Stream<AnnouncementState>.empty(),
        initialState: AnnouncementLoading(),
      );

      await _pumpRouted(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
        initial: mobileMoneyTrip,
      );
      await tester.pumpAndSettle();

      expect(find.text('Faire une demande'), findsOneWidget);
      verify(() => repository.getAnnouncementDetail('ann-trip-001')).called(1);
    });

    testWidgets('modèle de AnnouncementDetailLoaded : fromDetail vrai, '
        'aucune relecture', (tester) async {
      when(
        () => annBloc.state,
      ).thenReturn(AnnouncementDetailLoaded(mobileMoneyTrip));
      whenListen(
        annBloc,
        Stream<AnnouncementState>.value(
          AnnouncementDetailLoaded(mobileMoneyTrip),
        ),
        initialState: AnnouncementDetailLoaded(mobileMoneyTrip),
      );

      await _pumpRouted(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();

      expect(find.text('Faire une demande'), findsOneWidget);
      verifyNever(() => repository.getAnnouncementDetail(any()));
    });
  });

  testWidgets('propriétaire authentifié → écran propriétaire conservé', (
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

    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthAuthenticated(_owner),
    );

    await _pumpRouted(
      tester,
      annBloc: annBloc,
      bidBloc: bidBloc,
      cancelBloc: cancelBloc,
      authBloc: authBloc,
    );
    await tester.pumpAndSettle();

    expect(find.byType(TripOwnerDetailScreen), findsOneWidget);
    expect(find.text('Faire une demande'), findsNothing);
  });

  group('partage depuis l’en-tête', () {
    final shareButton = find.byKey(const Key('trip-owner-share-button'));

    testWidgets('propriétaire, trajet actif : icône de partage visible', (
      tester,
    ) async {
      await pumpOwnerWith(
        tester,
        announcement: _makeAnnouncement(),
        auth: const AuthAuthenticated(_owner),
      );

      expect(
        find.descendant(of: find.byType(AppBar), matching: shareButton),
        findsOneWidget,
      );
      // Le bouton du bas reste en place.
      expect(find.text('Affiche'), findsOneWidget);
    });

    testWidgets('l’icône ouvre la même affiche que la tuile « Affiche »', (
      tester,
    ) async {
      await pumpOwnerWith(
        tester,
        announcement: _makeAnnouncement(),
        auth: const AuthAuthenticated(_owner),
      );

      await tester.tap(shareButton);
      await tester.pumpAndSettle();
      expect(find.text('AFFICHE:ann-trip-001'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      final tile = find.byKey(const Key('trip-tile-poster'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('trip-tile-poster-button')));
      await tester.pumpAndSettle();
      expect(find.text('AFFICHE:ann-trip-001'), findsOneWidget);
    });

    testWidgets('trajet complet : pas d’icône (pas de tuile non plus)', (
      tester,
    ) async {
      await pumpOwnerWith(
        tester,
        announcement: _makeAnnouncement(status: 'FULL'),
        auth: const AuthAuthenticated(_owner),
      );

      expect(shareButton, findsNothing);
      expect(find.text('Affiche'), findsNothing);
    });

    testWidgets('visiteur non propriétaire : pas d’icône', (tester) async {
      final announcement = _makeAnnouncement();
      when(
        () => annBloc.state,
      ).thenReturn(AnnouncementDetailLoaded(announcement));
      whenListen(
        annBloc,
        const Stream<AnnouncementState>.empty(),
        initialState: AnnouncementDetailLoaded(announcement),
      );

      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );

      expect(shareButton, findsNothing);
    });
  });

  group('traductions', () {
    testWidgets('en anglais : AppBar + bouton d\'arrivée traduits', (
      tester,
    ) async {
      useEnglish();
      final announcement = _makeAnnouncement();
      when(
        () => annBloc.state,
      ).thenReturn(AnnouncementDetailLoaded(announcement));
      whenListen(
        annBloc,
        Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
        initialState: AnnouncementDetailLoaded(announcement),
      );

      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(_owner),
      );

      final bids = [_makeBid(status: 'IN_TRANSIT')];
      when(() => bidBloc.state).thenReturn(BidListLoaded(bids));
      whenListen(
        bidBloc,
        Stream<BidState>.value(BidListLoaded(bids)),
        initialState: BidListLoaded(bids),
      );

      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();

      expect(find.text('Trip'), findsOneWidget);
      expect(find.text('Arrived at destination'), findsOneWidget);
      expect(find.text('Trajet'), findsNothing);
    });

    // Relecture finale du lot K, constat 1 : ces snackbars affichaient le
    // `detail` français brut du serveur (`error.message`, via l'ancien champ
    // `String message`), jamais traduit en anglais. Ils passent désormais
    // par `ErrorPresenter.resolve`, qui route sur le code de l'exception et
    // rend le texte du catalogue.
    testWidgets(
      'en anglais : KYC requise affiche le texte du catalogue, jamais le detail serveur',
      (tester) async {
        useEnglish();
        final announcement = _makeAnnouncement();
        when(
          () => annBloc.state,
        ).thenReturn(AnnouncementDetailLoaded(announcement));
        whenListen(
          annBloc,
          Stream<AnnouncementState>.fromIterable([
            AnnouncementDetailLoaded(announcement),
            AnnouncementKycRequired(
              const ForbiddenException(
                'Vous devez vérifier votre identité pour continuer.',
                'kyc-not-verified',
              ),
            ),
          ]),
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

        expect(
          find.text('Verify your identity before posting a trip.'),
          findsOneWidget,
        );
        expect(
          find.text('Vous devez vérifier votre identité pour continuer.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'en anglais : date de départ passée affiche le texte du catalogue, jamais le detail serveur',
      (tester) async {
        useEnglish();
        final announcement = _makeAnnouncement();
        when(
          () => annBloc.state,
        ).thenReturn(AnnouncementDetailLoaded(announcement));
        whenListen(
          annBloc,
          // Un seul item (pas de doublon AnnouncementDetailLoaded avant) :
          // `_current` reste `null`, donc `_onDepartureDatePassed` s'arrête
          // avant de pousser `/trips/create` (route absente de ce routeur de
          // test, qui n'en a pas besoin pour vérifier le seul texte affiché).
          Stream<AnnouncementState>.fromIterable([
            AnnouncementDepartureDatePassed(
              const ValidationException(
                'La date de départ de ce trajet est déjà passée.',
                code: 'departure-date-passed',
              ),
            ),
          ]),
          initialState: AnnouncementDetailLoaded(announcement),
        );

        await _pump(
          tester,
          annBloc: annBloc,
          bidBloc: bidBloc,
          cancelBloc: cancelBloc,
          authBloc: authBloc,
        );
        // Pas de `pumpAndSettle` : `_current` reste `null` (voir plus haut),
        // donc le corps affiche `DonyDetailSkeleton`, dont le shimmer tourne
        // en boucle (`AnimationController.repeat()`) et ferait timeout.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('Change the departure date before posting this trip.'),
          findsOneWidget,
        );
        expect(
          find.text('La date de départ de ce trajet est déjà passée.'),
          findsNothing,
        );
      },
    );
  });

  // Les cas de « Arrivé à destination » (`tripCanMarkArrived`, ex-
  // `tripArrivalCtaFor`) sont dans `trip_owner/trip_arrival_test.dart`.

  // ── Annulation du trajet (FLUTTER-FH) ─────────────────────────────────────
  //
  // La feuille d'annulation se ferme avant l'envoi : l'écran écoute le succès,
  // prévient le voyageur et se recharge. Avant, il restait affiché inchangé et
  // le testeur a cru à un échec.
  group('annulation du trajet', () {
    CancellationModel cancellation({int parcelsToReturn = 0}) =>
        CancellationModel(
          announcementId: 'ann-trip-001',
          affectedBidsCount: 1,
          reason: 'Vol annulé',
          rematchSuggestions: const [],
          cancelledAt: DateTime(2026, 10, 8),
          parcelsToReturnCount: parcelsToReturn,
        );

    late StreamController<CancellationState> ctrl;

    setUp(() => ctrl = StreamController<CancellationState>.broadcast());
    tearDown(() => ctrl.close());

    Future<void> pumpWithCancellation(WidgetTester tester) async {
      whenListen(cancelBloc, ctrl.stream, initialState: CancellationInitial());
      await pumpOwnerWith(
        tester,
        announcement: _makeAnnouncement(),
        auth: const AuthAuthenticated(_owner),
      );
      registerFallbackValue(AnnouncementDetailRequested('fallback'));
      clearInteractions(annBloc);
      clearInteractions(bidBloc);
    }

    testWidgets('succès : snackbar et rechargement du trajet et des colis', (
      tester,
    ) async {
      await pumpWithCancellation(tester);

      ctrl.add(CancellationSuccess(cancellation()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Trajet annulé'), findsOneWidget);
      final reloads = verify(
        () => annBloc.add(captureAny()),
      ).captured.whereType<AnnouncementDetailRequested>();
      expect(reloads.single.id, 'ann-trip-001');
      final bidReloads = verify(
        () => bidBloc.add(captureAny()),
      ).captured.whereType<BidListRequested>();
      expect(bidReloads.single.announcementId, 'ann-trip-001');
    });

    testWidgets('succès avec un colis à restituer : le snackbar le dit', (
      tester,
    ) async {
      await pumpWithCancellation(tester);

      ctrl.add(CancellationSuccess(cancellation(parcelsToReturn: 1)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(
          'Trajet annulé. Rendez le colis remis : son expéditeur a reçu le '
          'code de retour.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('échec : message d\'erreur, pas de rechargement', (
      tester,
    ) async {
      await pumpWithCancellation(tester);

      ctrl.add(
        CancellationError(const ConflictException('Ce trajet est déjà annulé')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verifyNever(() => annBloc.add(any()));
      expect(find.text('Trajet annulé'), findsNothing);
    });

    testWidgets(
      'suppression bloquée : la feuille d\'annulation annonce le colis remis',
      (tester) async {
        final annCtrl = StreamController<AnnouncementState>.broadcast();
        addTearDown(annCtrl.close);
        final announcement = _makeAnnouncement();
        when(
          () => annBloc.state,
        ).thenReturn(AnnouncementDetailLoaded(announcement));
        whenListen(
          annBloc,
          annCtrl.stream,
          initialState: AnnouncementDetailLoaded(announcement),
        );
        when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
        whenListen(
          authBloc,
          const Stream<AuthState>.empty(),
          initialState: const AuthAuthenticated(_owner),
        );
        final bids = [_makeBid(status: 'HANDED_OVER')];
        when(() => bidBloc.state).thenReturn(BidListLoaded(bids));
        whenListen(
          bidBloc,
          Stream<BidState>.value(BidListLoaded(bids)),
          initialState: BidListLoaded(bids),
        );
        await _pump(
          tester,
          annBloc: annBloc,
          bidBloc: bidBloc,
          cancelBloc: cancelBloc,
          authBloc: authBloc,
        );
        await tester.pumpAndSettle();

        // L'état « suppression bloquée » remplace le détail (squelette animé) :
        // pas de pumpAndSettle tant que le dialogue puis la feuille s'ouvrent.
        annCtrl.add(AnnouncementDeleteBlockedByAcceptedBid('ann-trip-001'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('Annuler le voyage'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        expect(
          find.byKey(const Key('cancellation-handed-over-notice')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Un colis vous a déjà été remis : vous devrez le rendre à son '
            'expéditeur sous 3 jours, contre son code de retour.',
          ),
          findsOneWidget,
        );
      },
    );
  });

  // ── Écran assemblé ───────────────────────────────────────────────────────
  group('écran assemblé', () {
    void ownerOn(AnnouncementModel a, {List<BidModel> bids = const []}) {
      when(() => annBloc.state).thenReturn(AnnouncementDetailLoaded(a));
      whenListen(
        annBloc,
        const Stream<AnnouncementState>.empty(),
        initialState: AnnouncementDetailLoaded(a),
      );
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(_owner),
      );
      when(() => bidBloc.state).thenReturn(BidListLoaded(bids));
      whenListen(
        bidBloc,
        const Stream<BidState>.empty(),
        initialState: BidListLoaded(bids),
      );
    }

    Future<void> pumpScreen(WidgetTester tester) async {
      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
      );
      await tester.pumpAndSettle();
    }

    final stickyBar = find.byKey(const Key('trip-owner-sticky-bar'));
    final menuButton = find.byKey(const Key('trip-owner-menu-button'));

    testWidgets('retiré par l\'équipe : carte dédiée, ni pied, ni menu, ni '
        'partage', (tester) async {
      ownerOn(_makeAnnouncement(status: 'REMOVED_BY_ADMIN'));
      await pumpScreen(tester);

      expect(
        find.byKey(const Key('trip-status-card-removedByAdmin')),
        findsOneWidget,
      );
      expect(stickyBar, findsNothing);
      expect(menuButton, findsNothing);
      expect(find.byKey(const Key('trip-owner-share-button')), findsNothing);
      // Ni demandes ni colis à montrer.
      expect(find.byKey(const Key('trip-direct-request-card')), findsNothing);
      expect(find.byKey(const Key('trip-activity-row')), findsNothing);
      expect(find.byType(TripAudienceLine), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pied et menu selon le statut, hors du défilement', (
      tester,
    ) async {
      ownerOn(_makeAnnouncement(status: 'DRAFT'));
      await pumpScreen(tester);
      expect(find.byKey(const Key('trip-footer-publish')), findsOneWidget);
      expect(find.byKey(const Key('trip-footer-edit')), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppBar), matching: menuButton),
        findsOneWidget,
      );
      // Le pied n'est pas dans la colonne qui défile.
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: stickyBar,
        ),
        findsNothing,
      );

      ownerOn(_makeAnnouncement());
      await pumpScreen(tester);
      expect(find.byKey(const Key('trip-footer-sharePoster')), findsOneWidget);

      ownerOn(_makeAnnouncement(status: 'COMPLETED'));
      await pumpScreen(tester);
      expect(stickyBar, findsNothing);
    });

    testWidgets('demandes à traiter : « Voir les demandes », relu en silence '
        'au retour', (tester) async {
      ownerOn(_makeAnnouncement(), bids: [_makeBid(status: 'PENDING')]);
      await pumpScreen(tester);
      clearInteractions(bidBloc);
      clearInteractions(annBloc);

      await tester.tap(find.byKey(const Key('trip-footer-seeRequests')));
      await tester.pumpAndSettle();
      expect(
        find.text('DEMANDES:filter=aTraiter&announcement=ann-trip-001'),
        findsOneWidget,
      );
      verifyNever(() => bidBloc.add(any()));

      await tester.tap(find.textContaining('DEMANDES:'));
      await tester.pumpAndSettle();
      final bidEvent =
          verify(() => bidBloc.add(captureAny())).captured.single
              as BidListRequested;
      expect(bidEvent.silent, isTrue);
      registerFallbackValue(AnnouncementDetailRequested('fallback'));
      final annEvent = verify(
        () => annBloc.add(captureAny()),
      ).captured.whereType<AnnouncementDetailRequested>().single;
      expect(annEvent.silent, isTrue);
    });

    BidModel request(String id) => BidModel(
      id: id,
      announcementId: 'ann-trip-001',
      senderId: 'sender-$id',
      senderName: 'Expéditeur $id',
      weightKg: 2,
      status: 'PENDING',
      createdAt: DateTime(2026, 6),
      updatedAt: DateTime(2026, 6),
    );

    testWidgets('réponse directe : accepter passe à la demande suivante, '
        'l\'écran est relu en silence', (tester) async {
      final consent = _MockTrackingConsent();
      when(
        () => consent.onParcelAccepted(any()),
      ).thenAnswer((_) async => false);
      getIt.registerSingleton<TrackingConsentCubit>(consent);
      addTearDown(() => getIt.unregister<TrackingConsentCubit>());
      ownerOn(_makeAnnouncement(), bids: [request('r1'), request('r2')]);
      await pumpScreen(tester);
      clearInteractions(bidBloc);
      clearInteractions(annBloc);

      expect(find.text('Demande 1 sur 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('trip-request-accept-r1')));
      await tester.pump();
      await tester.pump();
      expect(answerEvents.single, isA<BidAcceptRequested>());
      // La réponse ne passe jamais par le BidBloc de la route.
      verifyNever(() => bidBloc.add(any(that: isA<BidAcceptRequested>())));

      answerStates.add(BidAccepted(request('r1')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Demande 1 sur 1'), findsOneWidget);
      expect(find.byKey(const Key('trip-direct-request-r2')), findsOneWidget);
      final reload =
          verify(() => bidBloc.add(captureAny())).captured.single
              as BidListRequested;
      expect(reload.silent, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('case Demandes : sheet des demandes, la ligne ouvre la fiche, '
        'relue en silence au retour', (tester) async {
      ownerOn(_makeAnnouncement(), bids: [request('r1'), request('r2')]);
      await pumpScreen(tester);
      clearInteractions(bidBloc);

      await tester.tap(find.byKey(const Key('trip-activity-requests')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('trip-activity-requests-content')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('trip-activity-request-r2')));
      await tester.pumpAndSettle();
      expect(find.text('BID:r2'), findsOneWidget);
      await tester.tap(find.text('BID:r2'));
      await tester.pumpAndSettle();
      final reload =
          verify(() => bidBloc.add(captureAny())).captured.single
              as BidListRequested;
      expect(reload.silent, isTrue);
    });

    testWidgets('« Voir les N demandes » : même sheet', (tester) async {
      ownerOn(_makeAnnouncement(), bids: [request('r1'), request('r2')]);
      await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('trip-direct-request-see-all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trip-activity-request-r1')), findsOneWidget);
      expect(find.byKey(const Key('trip-activity-request-r2')), findsOneWidget);
    });

    testWidgets('case Colis : tous les colis, « Ouvrir la liste des colis » '
        'puis relecture au retour', (tester) async {
      ownerOn(
        _makeAnnouncement(),
        bids: [
          _makeBid(status: 'ACCEPTED', id: 'c1'),
          _makeBid(status: 'IN_TRANSIT', id: 'c2'),
        ],
      );
      await pumpScreen(tester);
      clearInteractions(bidBloc);

      await tester.tap(find.byKey(const Key('trip-activity-parcels')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trip-activity-parcel-c1')), findsOneWidget);
      expect(find.byKey(const Key('trip-activity-parcel-c2')), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('trip-activity-parcels-open-list')),
      );
      await tester.pumpAndSettle();
      expect(find.text('PARCELS:ann-trip-001'), findsOneWidget);
      await tester.tap(find.text('PARCELS:ann-trip-001'));
      await tester.pumpAndSettle();
      verify(() => bidBloc.add(any(that: isA<BidListRequested>()))).called(1);
    });

    testWidgets('case Gain : son sheet, en lecture seule', (tester) async {
      ownerOn(_makeAnnouncement());
      await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('trip-activity-gain')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trip-activity-gain-empty')), findsOneWidget);
    });

    testWidgets('détail en échec sans trajet : erreur et « Réessayer », '
        'pas de squelette sans fin', (tester) async {
      when(
        () => annBloc.state,
      ).thenReturn(AnnouncementError(const NetworkException('offline')));
      whenListen(
        annBloc,
        const Stream<AnnouncementState>.empty(),
        initialState: AnnouncementError(const NetworkException('offline')),
      );
      await pumpScreen(tester);

      expect(find.byType(DonyDetailSkeleton), findsNothing);
      expect(find.byKey(const Key('trip-owner-load-error')), findsOneWidget);
      registerFallbackValue(AnnouncementDetailRequested('fallback'));
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      final event =
          verify(() => annBloc.add(captureAny())).captured.single
              as AnnouncementDetailRequested;
      expect(event.id, 'ann-trip-001');
      expect(event.silent, isFalse);
    });
  });
}
