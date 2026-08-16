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
}) => NegotiationThread(
  id: 't1',
  packageRequestId: 'pr1',
  travelerId: 'traveler-1',
  travelerTravelDate: DateTime(2026, 6, 15),
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
      expect(find.text('Confirme ta prise en charge'), findsOneWidget);
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
      expect(find.text('Confirme ta prise en charge'), findsNothing);
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

    testWidgets(
      'tap "Renoncer à ce colis" puis annuler → aucun dispatch',
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

        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();

        verifyNever(
          () => bloc.add(const NegotiationDeclineCommissionRequested('t1')),
        );
      },
    );

    testWidgets('compte à rebours : échéance future → "Il te reste …"', (
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

      expect(find.text('Il te reste 1h 45min'), findsOneWidget);
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
        expect(find.textContaining('Il te reste'), findsNothing);
        expect(find.text('Délai écoulé'), findsNothing);
      },
    );
  });

  group('showCommissionSettlementSheet', () {
    late bool retryCalled;
    late bool retryUseCard;

    setUp(() {
      retryCalled = false;
      retryUseCard = false;
    });

    Widget wrapSheet({
      required bool hasCard,
      double requiredCommission = 5,
      double availableBalance = 1,
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
                    onRetry: ({required useCard}) {
                      retryCalled = true;
                      retryUseCard = useCard;
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

    testWidgets(
      'solde insuffisant, hasCard → recharge et paiement par carte',
      (tester) async {
        await tester.pumpWidget(wrapSheet(hasCard: true));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('Solde insuffisant'), findsOneWidget);
        expect(
          find.textContaining(formatPriceIn(5, 'EUR')),
          findsOneWidget,
        );
        expect(
          find.textContaining(formatPriceIn(1, 'EUR')),
          findsOneWidget,
        );
        expect(find.text('Recharger mon portefeuille'), findsOneWidget);
        expect(find.text('Payer par carte'), findsOneWidget);
        expect(find.text('Ajouter une carte'), findsNothing);
      },
    );

    testWidgets('solde insuffisant, pas de carte → « Ajouter une carte »', (
      tester,
    ) async {
      await tester.pumpWidget(wrapSheet(hasCard: false));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Payer par carte'), findsNothing);
      expect(find.text('Ajouter une carte'), findsOneWidget);
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
      'tap "Recharger mon portefeuille" → navigue vers /payments/wallet/topup/method',
      (tester) async {
        await tester.pumpWidget(wrapSheet(hasCard: true));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Recharger mon portefeuille'));
        await tester.pumpAndSettle();

        expect(find.text('TOPUP_METHOD'), findsOneWidget);
        // onRetry n'est appelé qu'après une recharge réussie (résultat de la
        // route poussée) : pas encore ici, la route n'est pas résolue.
        expect(retryCalled, isFalse);
      },
    );
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

    testWidgets(
      'solde insuffisant → sheet avec recharge et carte',
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
        expect(find.text('Recharger mon portefeuille'), findsOneWidget);
        expect(find.text('Payer par carte'), findsOneWidget);
      },
    );

    testWidgets(
      'commission réglée → snackbar de succès et rafraîchit le fil',
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Le montage de l'écran déclenche déjà son propre chargement : on repart
        // de zéro pour n'observer que le rafraîchissement dû au règlement.
        clearInteractions(bloc);

        controller.add(const NegotiationCommissionSettled('t1'));
        // pump() ciblé, jamais pumpAndSettle : l'écran porte des timers (compte à
        // rebours, auto-fermeture de la snackbar) qui empêchent toute stabilisation.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Commission réglée : ce colis est à toi !'), findsOneWidget);
        verify(
          () => bloc.add(const NegotiationFetchRequested('t1')),
        ).called(1);

        // Flush the snackbar's auto-dismiss timer.
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'renoncement confirmé → snackbar puis retour arrière',
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

        final router = GoRouter(
          initialLocation: '/negotiations',
          routes: [
            GoRoute(
              path: '/negotiations',
              builder: (_, _) =>
                  const Scaffold(body: Text('LISTE_NEGOCIATIONS')),
            ),
            GoRoute(
              path: '/negotiations/:id',
              builder: (_, _) => NegotiationThreadScreen(
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
      },
    );
  });
}
