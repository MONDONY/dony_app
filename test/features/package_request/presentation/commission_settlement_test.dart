// Couvre le traitement du statut AWAITING_COMMISSION côté voyageur et
// expéditeur : bandeau + compte à rebours + CTA de règlement/renoncement
// (ThreadStateCtaBar), la sheet de solde insuffisant
// (commission_settlement_sheet.dart), et le câblage des états
// NegotiationCommissionInsufficientWallet / NegotiationCommissionSettled /
// NegotiationCommissionDeclined dans le listener de NegotiationThreadScreen.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/commission_funding_alternative.dart';
import 'package:dony/features/matching/data/models/commission_shortfall.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/presentation/screens/shared/negotiation_thread_screen.dart';
import 'package:dony/features/package_request/presentation/widgets/commission_settlement_sheet.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_state_banner.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_state_cta_bar.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../../helpers/mock_analytics_backend.dart';

const _emptyHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json);
  final String json;
  @override
  String get activatedJson => json;
  @override
  Future<String?> fetchAndActivate() async => json;
}

class _MockNegotiationBloc extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

const _viewerSender = 'sender-viewer';
const _viewerTraveler = 'traveler-1';

NegotiationThread _thread({
  required NegotiationThreadStatus status,
  String? commissionStatus,
  DateTime? commissionDeadline,
  double price = 38,
  DateTime? travelerTravelDate,
}) => NegotiationThread(
  id: 't1',
  packageRequestId: 'pr1',
  travelerId: 'traveler-1',
  // Voyage à venir par défaut : un jour de voyage passé désactive le
  // règlement (FLUTTER-44).
  travelerTravelDate:
      travelerTravelDate ??
      DateUtils.dateOnly(DateTime.now().add(const Duration(days: 30))),
  travelerAvailableKg: 10,
  status: status,
  currentPriceEur: price,
  roundsCount: 2,
  lastActivityAt: DateTime(2026, 5, 11, 10),
  createdAt: DateTime(2026, 5, 11, 9),
  messages: const [],
  commissionStatus: commissionStatus,
  commissionDeadline: commissionDeadline,
);

void main() {
  // Épingle le taux de commission : ces tests assertent des montants
  // calculés à 12 % (indépendants du défaut kDonyCommissionRateDefault).
  setUpAll(() => setDonyCommissionRate(0.12));
  tearDownAll(() => setDonyCommissionRate(kDonyCommissionRateDefault));

  setUp(() => DonySnackbar.clearDedup());

  group('ThreadStateCtaBar · AWAITING_COMMISSION', () {
    late _MockNegotiationBloc bloc;

    setUp(() {
      bloc = _MockNegotiationBloc();
      when(() => bloc.state).thenReturn(const NegotiationInitial());
      when(
        () => bloc.stream,
      ).thenAnswer((_) => const Stream<NegotiationState>.empty());
    });

    Widget wrap(NegotiationThread thread, String viewerUserId) => MaterialApp(
      theme: AppTheme.light(),
      home: BlocProvider<NegotiationBloc>.value(
        value: bloc,
        child: Scaffold(
          body: ThreadStateCtaBar(
            thread: thread,
            viewerUserId: viewerUserId,
            actionInProgress: false,
          ),
        ),
      ),
    );

    testWidgets('voyageur, commission en attente → CTA de règlement', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          _thread(
            status: NegotiationThreadStatus.awaitingCommission,
            commissionStatus: 'PENDING',
          ),
          _viewerTraveler,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Régler la commission'), findsOneWidget);
      expect(find.text('Confirmez votre prise en charge'), findsOneWidget);
      expect(find.text('Renoncer à ce colis'), findsOneWidget);
      // Montant de la commission affiché dans le bandeau.
      expect(
        find.textContaining(PriceDisplay.money(38 * 0.12, 'EUR')),
        findsOneWidget,
      );
    });

    testWidgets('expéditeur, même thread → aucun CTA de règlement', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          _thread(
            status: NegotiationThreadStatus.awaitingCommission,
            commissionStatus: 'PENDING',
          ),
          _viewerSender,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Régler la commission'), findsNothing);
      expect(find.byType(ThreadStateBanner), findsOneWidget);
      expect(
        find.text('En attente de la confirmation du voyageur'),
        findsOneWidget,
      );
      // Jamais laisser croire que l'affaire est conclue.
      expect(find.textContaining('reste ouverte'), findsOneWidget);
    });

    testWidgets('commission déjà réglée (ACCEPTED) → aucun CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          _thread(
            status: NegotiationThreadStatus.accepted,
            commissionStatus: 'CHARGED',
          ),
          _viewerTraveler,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Régler la commission'), findsNothing);
      expect(find.text('Confirmez votre prise en charge'), findsNothing);
    });

    testWidgets(
      'tap "Régler la commission" → dispatch NegotiationSettleCommissionRequested',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(
              status: NegotiationThreadStatus.awaitingCommission,
              commissionStatus: 'PENDING',
            ),
            _viewerTraveler,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Régler la commission'));
        await tester.pump();

        verify(
          () => bloc.add(const NegotiationSettleCommissionRequested('t1')),
        ).called(1);
      },
    );

    testWidgets(
      'tap "Renoncer à ce colis" puis confirmer → dispatch NegotiationDeclineCommissionRequested',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(
              status: NegotiationThreadStatus.awaitingCommission,
              commissionStatus: 'PENDING',
            ),
            _viewerTraveler,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Renoncer à ce colis'));
        await tester.pumpAndSettle();

        expect(find.text('Renoncer à ce colis ?'), findsOneWidget);

        await tester.tap(find.text('Renoncer'));
        await tester.pumpAndSettle();

        verify(
          () => bloc.add(const NegotiationDeclineCommissionRequested('t1')),
        ).called(1);
      },
    );

    testWidgets('tap "Renoncer à ce colis" puis annuler → aucun dispatch', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          _thread(
            status: NegotiationThreadStatus.awaitingCommission,
            commissionStatus: 'PENDING',
          ),
          _viewerTraveler,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Renoncer à ce colis'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      verifyNever(
        () => bloc.add(const NegotiationDeclineCommissionRequested('t1')),
      );
    });

    testWidgets('compte à rebours : échéance future → "Il vous reste …"', (
      tester,
    ) async {
      // +30s de marge sur la minute ronde : le moindre délai entre le calcul
      // de l'échéance ici et le DateTime.now() lu par initState() (quelques
      // millisecondes, inévitables) ferait sinon flotter l'assertion entre
      // "45min" et "44min" (Duration.inMinutes tronque).
      final deadline = DateTime.now().toUtc().add(
        const Duration(hours: 1, minutes: 45, seconds: 30),
      );
      await tester.pumpWidget(
        wrap(
          _thread(
            status: NegotiationThreadStatus.awaitingCommission,
            commissionStatus: 'PENDING',
            commissionDeadline: deadline,
          ),
          _viewerTraveler,
        ),
      );
      // Toujours démonter l'arbre, même si l'assertion ci-dessous échoue :
      // sinon le Timer.periodic du compte à rebours reste en vol et fait
      // planter pumpAndSettle() dans tous les tests suivants du fichier.
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pump();

      expect(find.text('Il vous reste 1h 45min'), findsOneWidget);
    });

    testWidgets(
      'compte à rebours : échéance dépassée → "Délai écoulé", pas de durée négative',
      (tester) async {
        final deadline = DateTime.now().toUtc().subtract(
          const Duration(minutes: 5),
        );
        await tester.pumpWidget(
          wrap(
            _thread(
              status: NegotiationThreadStatus.awaitingCommission,
              commissionStatus: 'PENDING',
              commissionDeadline: deadline,
            ),
            _viewerTraveler,
          ),
        );
        await tester.pump();

        expect(find.text('Délai écoulé'), findsOneWidget);
      },
    );

    testWidgets(
      'commissionDeadline absente → pas de compte à rebours, CTA visible quand même',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            _thread(
              status: NegotiationThreadStatus.awaitingCommission,
              commissionStatus: 'PENDING',
            ),
            _viewerTraveler,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Régler la commission'), findsOneWidget);
        expect(find.textContaining('Il vous reste'), findsNothing);
        expect(find.text('Délai écoulé'), findsNothing);
      },
    );
  });

  // FLUTTER-44 : le minuteur annonçait encore du temps pour régler la
  // commission alors que la date du voyage était passée.
  group('commission et date du voyage', () {
    late _MockNegotiationBloc bloc;

    setUp(() {
      bloc = _MockNegotiationBloc();
      when(() => bloc.state).thenReturn(const NegotiationInitial());
      when(
        () => bloc.stream,
      ).thenAnswer((_) => const Stream<NegotiationState>.empty());
    });

    Widget wrap(NegotiationThread thread) => MaterialApp(
      theme: AppTheme.light(),
      home: BlocProvider<NegotiationBloc>.value(
        value: bloc,
        child: Scaffold(
          body: ThreadStateCtaBar(
            thread: thread,
            viewerUserId: _viewerTraveler,
            actionInProgress: false,
          ),
        ),
      ),
    );

    testWidgets('voyage passé : message, pas de minuteur, bouton inactif', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          _thread(
            status: NegotiationThreadStatus.awaitingCommission,
            commissionStatus: 'PENDING',
            commissionDeadline: DateTime.now().toUtc().add(
              const Duration(hours: 1),
            ),
            travelerTravelDate: DateUtils.dateOnly(
              DateTime.now().subtract(const Duration(days: 2)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('commission-travel-date-passed')),
        findsOneWidget,
      );
      expect(find.textContaining('Il vous reste'), findsNothing);
      final button = tester.widget<DonyButton>(
        find.byKey(const Key('commission-pay-button')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('échéance dépassée : bouton inactif', (tester) async {
      await tester.pumpWidget(
        wrap(
          _thread(
            status: NegotiationThreadStatus.awaitingCommission,
            commissionStatus: 'PENDING',
            commissionDeadline: DateTime.now().toUtc().subtract(
              const Duration(minutes: 5),
            ),
          ),
        ),
      );
      await tester.pump();

      final button = tester.widget<DonyButton>(
        find.byKey(const Key('commission-pay-button')),
      );
      expect(button.onPressed, isNull);
    });

    test(
      'effectiveCommissionDeadline : plafonnée à la fin du jour du voyage',
      () {
        final travel = DateTime(2026, 10, 4);
        final travelEnd = DateTime(2026, 10, 5).toUtc();
        expect(
          effectiveCommissionDeadline(
            travelEnd.add(const Duration(days: 1)),
            travel,
          ),
          travelEnd,
        );
        final before = travelEnd.subtract(const Duration(hours: 3));
        expect(effectiveCommissionDeadline(before, travel), before);
        expect(effectiveCommissionDeadline(null, travel), isNull);
      },
    );

    test('isTravelDayOver : passé dès le lendemain du voyage', () {
      final travel = DateTime(2026, 10, 4);
      expect(isTravelDayOver(travel, DateTime(2026, 10, 4, 23, 59)), isFalse);
      expect(isTravelDayOver(travel, DateTime(2026, 10, 5)), isTrue);
    });
  });

  group('showCommissionSettlementSheet', () {
    late bool retryCalled;
    late bool retryUseCard;
    String? retryFundingCurrency;

    setUp(() {
      retryCalled = false;
      retryUseCard = false;
      retryFundingCurrency = null;
    });

    Widget wrapSheet({
      required bool hasCard,
      double requiredCommission = 5,
      double availableBalance = 1,
      CommissionShortfall? breakdown,
      String? bidCurrency,
      List<CommissionFundingAlternative> alternatives = const [],
    }) {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showCommissionSettlementSheet(
                    context,
                    requiredCommission: requiredCommission,
                    availableBalance: availableBalance,
                    hasCard: hasCard,
                    currency: 'EUR',
                    breakdown: breakdown,
                    bidCurrency: bidCurrency,
                    alternatives: alternatives,
                    onRetry: ({required useCard, fundingCurrency}) {
                      retryCalled = true;
                      retryUseCard = useCard;
                      retryFundingCurrency = fundingCurrency;
                    },
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/payments/wallet/topup/method',
            builder: (_, _) => const Scaffold(body: Text('TOPUP_METHOD')),
          ),
          GoRoute(
            path: '/payments/commission-method',
            builder: (_, _) => const Scaffold(body: Text('COMMISSION_METHOD')),
          ),
        ],
      );
      return MaterialApp.router(theme: AppTheme.light(), routerConfig: router);
    }

    testWidgets('solde insuffisant, hasCard → recharge et paiement par carte', (
      tester,
    ) async {
      await tester.pumpWidget(wrapSheet(hasCard: true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Solde insuffisant'), findsOneWidget);
      expect(find.textContaining(formatPriceIn(5, 'EUR')), findsOneWidget);
      expect(find.textContaining(formatPriceIn(1, 'EUR')), findsOneWidget);
      expect(find.text('Recharger en EUR'), findsOneWidget);
      expect(find.text('Payer par carte'), findsOneWidget);
      expect(find.text('Ajouter une carte'), findsNothing);
    });

    testWidgets('solde insuffisant, pas de carte → « Ajouter une carte »', (
      tester,
    ) async {
      await tester.pumpWidget(wrapSheet(hasCard: false));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Payer par carte'), findsNothing);
      expect(find.text('Ajouter une carte'), findsOneWidget);
    });

    testWidgets('avec breakdown → détail portefeuille par portefeuille', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapSheet(
          hasCard: true,
          breakdown: const CommissionShortfall(
            bidCurrency: 'XOF',
            commission: 1050,
            coveredByBidWallet: 600,
            remainingBid: 450,
            remainingInActive: 0.69,
            activeCurrency: 'EUR',
            activeBalance: 1.33,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Solde insuffisant'), findsOneWidget);
      expect(find.textContaining('en couvre'), findsOneWidget);
      expect(find.textContaining('Commission requise'), findsNothing);
    });

    testWidgets(
      'tap "Payer par carte" → ferme la sheet et appelle onRetry(useCard: true)',
      (tester) async {
        await tester.pumpWidget(wrapSheet(hasCard: true));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Payer par carte'));
        await tester.pumpAndSettle();

        expect(find.text('Solde insuffisant'), findsNothing);
        expect(retryCalled, isTrue);
        expect(retryUseCard, isTrue);
      },
    );

    testWidgets(
      'tap "Recharger en EUR" → navigue vers /payments/wallet/topup/method',
      (tester) async {
        await tester.pumpWidget(wrapSheet(hasCard: true));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Recharger en EUR'));
        await tester.pumpAndSettle();

        expect(find.text('TOPUP_METHOD'), findsOneWidget);
        // onRetry n'est appelé qu'après une recharge réussie (résultat de la
        // route poussée) : pas encore ici, la route n'est pas résolue.
        expect(retryCalled, isFalse);
      },
    );

    // ── FLUTTER-CG : autre portefeuille au taux du jour ─────────────────────

    testWidgets(
      'alternative XOF : option, montant au taux du jour et avertissement',
      (tester) async {
        await tester.pumpWidget(
          wrapSheet(
            hasCard: true,
            bidCurrency: 'EUR',
            availableBalance: 0,
            alternatives: const [
              CommissionFundingAlternative(
                currency: 'XOF',
                balance: 12000,
                requiredAmount: 656,
              ),
            ],
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('Recharger en EUR'), findsOneWidget);
        expect(
          find.textContaining('Solde du portefeuille EUR'),
          findsOneWidget,
        );
        expect(find.text('Payer avec mon solde XOF'), findsOneWidget);
        expect(
          find.text('≈ ${formatPriceIn(656, 'XOF')} au taux du jour'),
          findsOneWidget,
        );
        expect(
          find.textContaining("Yadony n'est pas responsable"),
          findsOneWidget,
        );

        await tester.ensureVisible(find.text('Payer avec mon solde XOF'));
        await tester.tap(find.text('Payer avec mon solde XOF'));
        await tester.pumpAndSettle();

        expect(find.text('Solde insuffisant'), findsNothing);
        expect(retryCalled, isTrue);
        expect(retryUseCard, isFalse);
        expect(retryFundingCurrency, 'XOF');
      },
    );

    testWidgets('sans alternative : ni option ni avertissement', (
      tester,
    ) async {
      await tester.pumpWidget(wrapSheet(hasCard: true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Payer avec mon solde'), findsNothing);
      expect(find.textContaining('taux du jour'), findsNothing);
    });

    testWidgets('anglais : titre, hint et boutons traduits', (tester) async {
      useEnglish();
      await tester.pumpWidget(wrapSheet(hasCard: true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Insufficient balance'), findsOneWidget);
      expect(
        find.textContaining('Top up your wallet or pay the service fee'),
        findsOneWidget,
      );
      expect(find.text('Top up in EUR'), findsOneWidget);
      expect(find.text('Pay by card'), findsOneWidget);
    });
  });

  group('NegotiationThreadScreen · listener commission', () {
    late _MockNegotiationBloc bloc;

    setUp(() {
      bloc = _MockNegotiationBloc();
      when(() => bloc.state).thenReturn(const NegotiationInitial());
      when(
        () => bloc.stream,
      ).thenAnswer((_) => const Stream<NegotiationState>.empty());

      if (getIt.isRegistered<NegotiationBloc>()) {
        getIt.unregister<NegotiationBloc>();
      }
      getIt.registerFactory<NegotiationBloc>(() => bloc);
    });

    tearDown(() {
      if (getIt.isRegistered<NegotiationBloc>()) {
        getIt.unregister<NegotiationBloc>();
      }
    });

    Widget wrap({String viewerUserId = _viewerTraveler}) =>
        BlocProvider<HelpCenterBloc>(
          create: (_) => HelpCenterBloc(
            HelpCenterRepository(
              const _StaticHelpCenterSource(_emptyHelpConfigJson),
              fallbackJsonLoader: () async => _emptyHelpConfigJson,
            ),
            makeDisabledAnalytics(MockAnalyticsBackend()),
          )..add(const HelpCenterLoadRequested()),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: NegotiationThreadScreen(
              threadId: 't1',
              viewerUserId: viewerUserId,
            ),
          ),
        );

    // L'écran de succès est une route GoRouter : le fil est monté sous un
    // routeur, avec un stub de la route poussée.
    Widget wrapRouted() => BlocProvider<HelpCenterBloc>(
      create: (_) => HelpCenterBloc(
        HelpCenterRepository(
          const _StaticHelpCenterSource(_emptyHelpConfigJson),
          fallbackJsonLoader: () async => _emptyHelpConfigJson,
        ),
        makeDisabledAnalytics(MockAnalyticsBackend()),
      )..add(const HelpCenterLoadRequested()),
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: GoRouter(
          initialLocation: '/negotiations/t1',
          routes: [
            GoRoute(
              path: '/negotiations/:id/commission-settled',
              builder: (_, state) => Scaffold(
                body: Text('Succès commission ${state.pathParameters['id']}'),
              ),
            ),
            GoRoute(
              path: '/negotiations/:id',
              builder: (_, _) => const NegotiationThreadScreen(
                threadId: 't1',
                viewerUserId: _viewerTraveler,
              ),
            ),
          ],
        ),
      ),
    );

    testWidgets('solde insuffisant → sheet avec recharge et carte', (
      tester,
    ) async {
      final controller = StreamController<NegotiationState>();
      addTearDown(controller.close);
      whenListen(
        bloc,
        controller.stream,
        initialState: NegotiationLoaded(
          _thread(
            status: NegotiationThreadStatus.awaitingCommission,
            commissionStatus: 'PENDING',
          ),
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      controller.add(
        const NegotiationCommissionInsufficientWallet(
          availableBalance: 1,
          requiredCommission: 5,
          hasCard: true,
          threadId: 't1',
          currency: 'EUR',
        ),
      );
      // pump() cible, jamais pumpAndSettle : l ecran porte des timers (compte a
      // rebours, auto-fermeture de la snackbar) qui empechent toute stabilisation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Solde insuffisant'), findsOneWidget);
      expect(find.text('Recharger en EUR'), findsOneWidget);
      expect(find.text('Payer par carte'), findsOneWidget);
    });

    testWidgets(
      'solde insuffisant avec breakdown → détail portefeuille par portefeuille',
      (tester) async {
        final controller = StreamController<NegotiationState>();
        addTearDown(controller.close);
        whenListen(
          bloc,
          controller.stream,
          initialState: NegotiationLoaded(
            _thread(
              status: NegotiationThreadStatus.awaitingCommission,
              commissionStatus: 'PENDING',
            ),
          ),
        );

        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        controller.add(
          const NegotiationCommissionInsufficientWallet(
            availableBalance: 1.33,
            requiredCommission: 1.60,
            hasCard: true,
            threadId: 't1',
            currency: 'EUR',
            breakdown: CommissionShortfall(
              bidCurrency: 'XOF',
              commission: 1050,
              coveredByBidWallet: 600,
              remainingBid: 450,
              remainingInActive: 0.69,
              activeCurrency: 'EUR',
              activeBalance: 1.33,
            ),
          ),
        );
        // pump() cible, jamais pumpAndSettle : l ecran porte des timers (compte a
        // rebours, auto-fermeture de la snackbar) qui empechent toute stabilisation.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Solde insuffisant'), findsOneWidget);
        expect(find.textContaining('en couvre'), findsOneWidget);
      },
    );

    // Sentry FLUTTER-7N : la snackbar furtive passait inaperçue au retour
    // d'une recharge, un écran de succès la remplace.
    testWidgets('commission réglée → écran de succès et rafraîchit le fil', (
      tester,
    ) async {
      final controller = StreamController<NegotiationState>();
      addTearDown(controller.close);
      whenListen(
        bloc,
        controller.stream,
        initialState: NegotiationLoaded(
          _thread(
            status: NegotiationThreadStatus.awaitingCommission,
            commissionStatus: 'PENDING',
          ),
        ),
      );

      await tester.pumpWidget(wrapRouted());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Le montage de l'écran déclenche déjà son propre chargement : on repart
      // de zéro pour n'observer que le rafraîchissement dû au règlement.
      clearInteractions(bloc);

      controller.add(const NegotiationCommissionSettled('t1'));
      // pump() ciblé, jamais pumpAndSettle : l'écran porte des timers (compte à
      // rebours) qui empêchent toute stabilisation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Succès commission t1'), findsOneWidget);
      expect(
        find.text('Commission réglée : ce colis est à vous !'),
        findsNothing,
      );
      verify(() => bloc.add(const NegotiationFetchRequested('t1'))).called(1);
    });

    testWidgets('renoncement confirmé → snackbar puis retour arrière', (
      tester,
    ) async {
      final controller = StreamController<NegotiationState>();
      addTearDown(controller.close);
      whenListen(
        bloc,
        controller.stream,
        initialState: NegotiationLoaded(
          _thread(
            status: NegotiationThreadStatus.awaitingCommission,
            commissionStatus: 'PENDING',
          ),
        ),
      );

      final router = GoRouter(
        initialLocation: '/negotiations',
        routes: [
          GoRoute(
            path: '/negotiations',
            builder: (_, _) => const Scaffold(body: Text('LISTE_NEGOCIATIONS')),
          ),
          GoRoute(
            path: '/negotiations/:id',
            builder: (_, _) => const NegotiationThreadScreen(
              threadId: 't1',
              viewerUserId: _viewerTraveler,
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        BlocProvider<HelpCenterBloc>(
          create: (_) => HelpCenterBloc(
            HelpCenterRepository(
              const _StaticHelpCenterSource(_emptyHelpConfigJson),
              fallbackJsonLoader: () async => _emptyHelpConfigJson,
            ),
            makeDisabledAnalytics(MockAnalyticsBackend()),
          )..add(const HelpCenterLoadRequested()),
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(router.push('/negotiations/t1'));
      await tester.pumpAndSettle();

      controller.add(const NegotiationCommissionDeclined('t1'));
      await tester.pumpAndSettle();

      expect(find.text('LISTE_NEGOCIATIONS'), findsOneWidget);

      // Flush the snackbar's auto-dismiss timer.
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
