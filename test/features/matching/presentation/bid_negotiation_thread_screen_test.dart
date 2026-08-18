import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_bloc.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_state.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/presentation/screens/bid_negotiation_thread_screen.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/error_reporting_test_doubles.dart';

class _MockNegotiationBloc
    extends MockBloc<BidNegotiationEvent, BidNegotiationState>
    implements BidNegotiationBloc {}

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockLocalAuthService extends Mock implements LocalAuthService {}

class _MockBox extends Mock implements Box {}

class _MockPaymentGateway extends Mock implements PaymentGateway {}

class _MockPaymentRepository extends Mock implements PaymentRepository {}

/// [HiveService.userPrefs] ouvre une vraie box Hive, remplacée ici pour que
/// `requirePaymentAuth` lise un mock sans toucher au disque.
class _FakeHiveService extends HiveService {
  _FakeHiveService(this._box);
  final Box _box;

  @override
  Box get userPrefs => _box;
}

const _kSettle = Duration(milliseconds: 600);

BidNegotiation _thread({
  bool myTurn = true,
  bool canCounter = true,
  double? netEur,
  // Par défaut, le rôle suit la présence du net : c'est ce que le serveur
  // produit sur un fil qui porte un montant, et ça garde leur sens aux appels
  // qui passent `netEur` pour dire « vue voyageur ». À forcer explicitement
  // pour tester un voyageur SANS montant proposé, le cas que la déduction
  // `netEur != null` traitait à tort comme un expéditeur.
  String? role,
  String status = 'NEGOTIATING',
  int round = 1,
  List<BidNegotiationMessage> messages = const [
    BidNegotiationMessage(
      id: 'm1',
      kind: BidNegotiationMessageKind.proposal,
      authorId: 'sender-1',
      proposedGrossEur: 42,
      body: 'Je propose 42 euros pour le tout.',
    ),
  ],
}) => BidNegotiation(
  bidId: 'bid1',
  announcementId: 'ann1',
  status: status,
  role: role ?? (netEur != null ? 'TRAVELER' : 'SENDER'),
  round: round,
  maxRounds: 6,
  myTurn: myTurn,
  canCounter: canCounter,
  proposedGrossEur: 42,
  netEur: netEur,
  commissionEur: netEur == null ? null : 5,
  weightKg: 3,
  description: 'Deux paires de chaussures',
  contentCategory: 'Chaussures',
  gridItems: const [
    BidGridLine(
      id: 'g1',
      label: 'Carton moyen',
      unitPriceDisplayEur: 12,
      quantity: 1,
    ),
  ],
  customItems: const [
    BidCustomItem(id: 'c1', label: 'Sac de riz', quantity: 2, amountEur: 9),
  ],
  photoUrls: const ['https://example.test/photo-1.jpg'],
  counterpartyName: 'Mamadou Diallo',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  messages: messages,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockNegotiationBloc bloc;
  late _MockPaymentBloc paymentBloc;
  late _MockBidBloc bidBloc;
  late _MockLocalAuthService authService;
  late _MockBox userPrefsBox;
  late _MockPaymentGateway paymentGateway;

  void register<T extends Object>(T Function() factory) {
    if (getIt.isRegistered<T>()) getIt.unregister<T>();
    getIt.registerFactory<T>(factory);
  }

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(const BidNegotiationFetchRequested('fallback'));
    registerFallbackValue(const PaymentInitial());
    registerFallbackValue(BidInitial());
    registerFallbackValue(
      const BidCheckoutPaymentRequested(
        clientSecret: '',
        publishableKey: '',
        bidId: '',
        amountEur: 0,
      ),
    );
    registerFallbackValue(BidConfirmPaymentRequested(''));
  });

  setUp(() {
    registerNoopErrorReporting();

    bloc = _MockNegotiationBloc();

    paymentBloc = _MockPaymentBloc();
    when(() => paymentBloc.state).thenReturn(const PaymentInitial());
    when(() => paymentBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => paymentBloc.close()).thenAnswer((_) async {});

    bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => bidBloc.close()).thenAnswer((_) async {});

    // Biométrie activée et réussie : `requirePaymentAuth` ne passe jamais par
    // l'écran PIN, aucune route stub n'est nécessaire.
    authService = _MockLocalAuthService();
    userPrefsBox = _MockBox();
    when(
      () => userPrefsBox.get(
        HiveService.kBiometricEnabled,
        defaultValue: any(named: 'defaultValue'),
      ),
    ).thenReturn(true);
    when(
      () => authService.isBiometricAvailable(),
    ).thenAnswer((_) async => true);
    when(
      () => authService.authenticateWithBiometric(),
    ).thenAnswer((_) async => true);

    // PlatformPayButton (Apple/Google Pay) plante hors device réel : on paie
    // par PayPal, un bouton Flutter classique.
    paymentGateway = _MockPaymentGateway();
    when(
      () => paymentGateway.isPlatformPaySupported(),
    ).thenAnswer((_) async => false);
    when(() => paymentGateway.confirmPayPal(any())).thenAnswer((_) async {});

    register<PaymentBloc>(() => paymentBloc);
    register<BidBloc>(() => bidBloc);
    register<LocalAuthService>(() => authService);
    register<HiveService>(() => _FakeHiveService(userPrefsBox));
    register<PaymentGateway>(() => paymentGateway);
    register<PaymentRepository>(_MockPaymentRepository.new);
  });

  tearDown(() {
    for (final unregister in [
      () => getIt.unregister<PaymentBloc>(),
      () => getIt.unregister<BidBloc>(),
      () => getIt.unregister<LocalAuthService>(),
      () => getIt.unregister<HiveService>(),
      () => getIt.unregister<PaymentGateway>(),
      () => getIt.unregister<PaymentRepository>(),
    ]) {
      unregister();
    }
  });

  /// Monte l'écran sur un bloc déjà stubé, pour les tests qui pilotent
  /// eux-mêmes le flux d'états.
  Widget wrapWithBloc() {
    return BlocProvider<BidNegotiationBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) =>
                  const BidNegotiationThreadScreen(bidId: 'bid1'),
            ),
          ],
        ),
      ),
    );
  }

  Widget wrap(BidNegotiationState state) {
    whenListen(
      bloc,
      const Stream<BidNegotiationState>.empty(),
      initialState: state,
    );
    return wrapWithBloc();
  }

  /// Écran POUSSÉ sur la pile, comme en production depuis la liste des
  /// discussions : `context.pop(true)` après un paiement réussi a alors bien
  /// quelque chose à dépiler.
  Widget wrapPushed() {
    return BlocProvider<BidNegotiationBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: Builder(
                  builder: (inner) => TextButton(
                    onPressed: () => inner.push('/thread'),
                    child: const Text('Ouvrir'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/thread',
              builder: (_, _) =>
                  const BidNegotiationThreadScreen(bidId: 'bid1'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> pumpScreen(WidgetTester tester, BidNegotiationState s) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(s));
    await tester.pump(_kSettle);
  }

  testWidgets('l etat de chargement affiche un indicateur', (tester) async {
    await pumpScreen(tester, const BidNegotiationLoading());

    expect(find.byKey(const Key('nego-loading')), findsOneWidget);
  });

  // Le chassis du design system porte l ombre de la barre collante, le padding
  // responsive, la largeur max sur tablette et l inset clavier. Les remonter a
  // la main, comme le faisait cet ecran, revenait a les perdre un par un.
  testWidgets('l ecran s appuie sur le chassis DonyPageScaffold', (
    tester,
  ) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread(netEur: 37)));

    expect(find.byType(DonyPageScaffold), findsOneWidget);
  });

  testWidgets('l etat d erreur propose de reessayer', (tester) async {
    await pumpScreen(tester, const BidNegotiationError(OfflineException()));

    expect(find.byKey(const Key('nego-error')), findsOneWidget);
    // L etat d erreur est celui du design system, pas une reimplementation.
    expect(find.byType(DonyEmptyState), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pump(_kSettle);

    final refetch = verify(
      () => bloc.add(captureAny()),
    ).captured.whereType<BidNegotiationFetchRequested>().toList();
    expect(refetch, isNotEmpty);
  });

  testWidgets('le fil charge affiche le recapitulatif complet du colis', (
    tester,
  ) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread(netEur: 37)));

    expect(find.textContaining('3 kg'), findsWidgets);
    expect(find.text('Carton moyen'), findsOneWidget);
    expect(find.text('Sac de riz'), findsOneWidget);
    expect(find.text('Deux paires de chaussures'), findsOneWidget);
    expect(find.byKey(const Key('nego-photo-0')), findsOneWidget);
    expect(find.text('Je propose 42 euros pour le tout.'), findsOneWidget);
  });

  testWidgets('les trois actions sont la quand c est mon tour', (tester) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread()));

    expect(find.byKey(const Key('nego-accept-btn')), findsOneWidget);
    expect(find.byKey(const Key('nego-counter-btn')), findsOneWidget);
    expect(find.byKey(const Key('nego-reject-btn')), findsOneWidget);
    expect(find.byKey(const Key('nego-waiting-hint')), findsNothing);
  });

  testWidgets('les actions disparaissent quand c est le tour de l autre', (
    tester,
  ) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread(myTurn: false)));

    expect(find.byKey(const Key('nego-accept-btn')), findsNothing);
    expect(find.byKey(const Key('nego-counter-btn')), findsNothing);
    expect(find.byKey(const Key('nego-reject-btn')), findsNothing);
    expect(find.byKey(const Key('nego-waiting-hint')), findsOneWidget);
  });

  testWidgets('au plafond de tours la contre-offre est desactivee', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      BidNegotiationLoaded(_thread(canCounter: false, round: 6)),
    );

    final counter = tester.widget<DonyButton>(
      find.byKey(const Key('nego-counter-btn')),
    );
    expect(counter.onPressed, isNull);
    final accept = tester.widget<DonyButton>(
      find.byKey(const Key('nego-accept-btn')),
    );
    expect(accept.onPressed, isNotNull);
  });

  testWidgets('le voyageur voit son net, jamais le total brut seul', (
    tester,
  ) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread(netEur: 37)));

    expect(find.byKey(const Key('nego-net-amount')), findsOneWidget);
    expect(find.textContaining('37'), findsWidgets);
  });

  testWidgets('l expediteur voit le total, sans ligne de net', (tester) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread()));

    expect(find.byKey(const Key('nego-net-amount')), findsNothing);
    expect(find.byKey(const Key('nego-total-amount')), findsOneWidget);
  });

  testWidgets('l ouverture marque le fil comme lu', (tester) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread()));

    final read = verify(
      () => bloc.add(captureAny()),
    ).captured.whereType<BidNegotiationReadRequested>().toList();
    expect(read, hasLength(1));
    expect(read.single.bidId, 'bid1');
  });

  testWidgets('accepter emet BidNegotiationAcceptRequested', (tester) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread()));

    await tester.tap(find.byKey(const Key('nego-accept-btn')));
    await tester.pump(_kSettle);

    final accepted = verify(
      () => bloc.add(captureAny()),
    ).captured.whereType<BidNegotiationAcceptRequested>().toList();
    expect(accepted, hasLength(1));
  });

  testWidgets('refuser emet BidNegotiationRejectRequested', (tester) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread()));

    await tester.tap(find.byKey(const Key('nego-reject-btn')));
    await tester.pump(_kSettle);

    final rejected = verify(
      () => bloc.add(captureAny()),
    ).captured.whereType<BidNegotiationRejectRequested>().toList();
    expect(rejected, hasLength(1));
  });

  testWidgets('un fil clos n affiche plus aucune action', (tester) async {
    await pumpScreen(
      tester,
      BidNegotiationLoaded(_thread(status: 'ACCEPTED', myTurn: false)),
    );

    expect(find.byKey(const Key('nego-accept-btn')), findsNothing);
    expect(find.byKey(const Key('nego-closed-hint')), findsOneWidget);
  });

  // Le serveur n'envoie plus qu'un seul statut de clôture, NEGOTIATION_CLOSED,
  // pour ne plus recycler les statuts de colis. La raison se relit sur le fil.
  group('fil eteint : refus ou peremption', () {
    testWidgets('un message REJECT signe une fermeture par une des parties', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        BidNegotiationLoaded(
          _thread(
            status: 'NEGOTIATION_CLOSED',
            myTurn: false,
            messages: const [
              BidNegotiationMessage(
                id: 'm1',
                kind: BidNegotiationMessageKind.proposal,
                authorId: 'sender-1',
                proposedGrossEur: 42,
              ),
              BidNegotiationMessage(
                id: 'm2',
                kind: BidNegotiationMessageKind.reject,
                authorId: 'traveler-1',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Proposition refusée.'), findsOneWidget);
    });

    testWidgets('sans message REJECT, le fil a simplement péri', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        BidNegotiationLoaded(
          _thread(
            status: 'NEGOTIATION_CLOSED',
            myTurn: false,
            messages: const [
              BidNegotiationMessage(
                id: 'm1',
                kind: BidNegotiationMessageKind.proposal,
                authorId: 'sender-1',
                proposedGrossEur: 42,
              ),
            ],
          ),
        ),
      );

      // Le balayage d'expiration ne poste aucun message : son absence est le
      // seul signal disponible, et il ne dépend pas de l'ordre de tri.
      expect(find.text('Proposition expirée.'), findsOneWidget);
    });
  });

  // ── Après accord : carte vs espèces ────────────────────────────────────────

  group('etat d apres-accord', () {
    testWidgets('accord carte cote expediteur : bouton Payer', (tester) async {
      await pumpScreen(
        tester,
        BidNegotiationLoaded(
          _thread(status: 'AWAITING_PAYMENT', myTurn: false),
        ),
      );

      expect(find.byKey(const Key('nego-pay-btn')), findsOneWidget);
      expect(find.text('Payer'), findsOneWidget);
      expect(find.byKey(const Key('nego-closed-hint')), findsNothing);
      expect(
        find.byKey(const Key('nego-awaiting-traveler-hint')),
        findsNothing,
      );
    });

    testWidgets('taper Payer emet BidNegotiationCheckoutRequested', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        BidNegotiationLoaded(
          _thread(status: 'AWAITING_PAYMENT', myTurn: false),
        ),
      );

      await tester.tap(find.byKey(const Key('nego-pay-btn')));
      await tester.pump(_kSettle);

      final checkout = verify(
        () => bloc.add(captureAny()),
      ).captured.whereType<BidNegotiationCheckoutRequested>().toList();
      expect(checkout, hasLength(1));
      expect(checkout.single.bidId, 'bid1');
    });

    testWidgets('accord carte cote voyageur : aucun paiement a declencher', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        BidNegotiationLoaded(
          _thread(status: 'AWAITING_PAYMENT', myTurn: false, netEur: 37),
        ),
      );

      expect(find.byKey(const Key('nego-pay-btn')), findsNothing);
      expect(
        find.byKey(const Key('nego-awaiting-payment-hint')),
        findsOneWidget,
      );
    });

    testWidgets(
      'accepter un accord carte cote expediteur garde le fil ouvert pour payer',
      (tester) async {
        final states = StreamController<BidNegotiationState>.broadcast();
        addTearDown(states.close);
        whenListen(
          bloc,
          states.stream,
          initialState: BidNegotiationLoaded(_thread()),
        );

        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(wrapPushed());
        await tester.pump(_kSettle);
        await tester.tap(find.text('Ouvrir'));
        await tester.pump(_kSettle);
        await tester.pump(_kSettle);

        states.add(
          BidNegotiationLoaded(
            _thread(status: 'AWAITING_PAYMENT', myTurn: false),
            action: BidNegotiationAction.accepted,
          ),
        );
        await tester.pump(_kSettle);
        await tester.pump(_kSettle);

        expect(find.byKey(const Key('nego-pay-btn')), findsOneWidget);
        expect(find.text('Ouvrir'), findsNothing);
      },
    );

    testWidgets(
      'accepter cote voyageur referme le fil en signalant le change',
      (tester) async {
        final states = StreamController<BidNegotiationState>.broadcast();
        addTearDown(states.close);
        whenListen(
          bloc,
          states.stream,
          initialState: BidNegotiationLoaded(_thread(netEur: 37)),
        );

        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(wrapPushed());
        await tester.pump(_kSettle);
        await tester.tap(find.text('Ouvrir'));
        await tester.pump(_kSettle);
        await tester.pump(_kSettle);

        states.add(
          BidNegotiationLoaded(
            _thread(status: 'AWAITING_PAYMENT', myTurn: false, netEur: 37),
            action: BidNegotiationAction.accepted,
          ),
        );
        await tester.pump(_kSettle);
        await tester.pump(_kSettle);

        expect(find.text('Ouvrir'), findsOneWidget);
      },
    );

    testWidgets('accord en especes : attente du voyageur, aucun paiement', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        BidNegotiationLoaded(_thread(status: 'PENDING', myTurn: false)),
      );

      expect(find.byKey(const Key('nego-pay-btn')), findsNothing);
      expect(
        find.byKey(const Key('nego-awaiting-traveler-hint')),
        findsOneWidget,
      );
    });
  });

  // ── Enchaînement sur le parcours de paiement carte existant ────────────────

  group('paiement de l accord', () {
    BidCheckoutResponseModel checkout({
      List<String> types = const ['paypal'],
    }) => BidCheckoutResponseModel(
      bidId: 'bid1',
      clientSecret: 'pi_1_secret_2',
      publishableKey: 'pk_test_1',
      expiresAt: DateTime.utc(2026, 8, 19, 4, 12),
      currency: 'eur',
      paymentMethodTypes: types,
    );

    testWidgets(
      'BidNegotiationCheckoutReady dispatche BidCheckoutPaymentRequested',
      (tester) async {
        final states = StreamController<BidNegotiationState>.broadcast();
        addTearDown(states.close);
        whenListen(
          bloc,
          states.stream,
          initialState: BidNegotiationLoaded(
            _thread(status: 'AWAITING_PAYMENT', myTurn: false),
          ),
        );

        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(wrapWithBloc());
        await tester.pump(_kSettle);

        states.add(
          BidNegotiationCheckoutReady(
            checkout(),
            negotiation: _thread(status: 'AWAITING_PAYMENT', myTurn: false),
          ),
        );
        await tester.pump();
        await tester.pump();

        final dispatched = verify(
          () => paymentBloc.add(captureAny()),
        ).captured.whereType<BidCheckoutPaymentRequested>().toList();
        expect(dispatched, hasLength(1));
        expect(dispatched.single.clientSecret, 'pi_1_secret_2');
        expect(dispatched.single.bidId, 'bid1');
        expect(dispatched.single.amountEur, 42);
        expect(dispatched.single.currencyCode, 'eur');
        expect(dispatched.single.paymentMethodTypes, ['paypal']);
      },
    );

    testWidgets(
      'CheckoutPaymentSheetReady authentifie puis ouvre la feuille, et le '
      'succes confirme le paiement',
      (tester) async {
        final paymentStates = StreamController<PaymentState>.broadcast();
        addTearDown(paymentStates.close);
        when(() => paymentBloc.stream).thenAnswer((_) => paymentStates.stream);
        whenListen(
          bloc,
          const Stream<BidNegotiationState>.empty(),
          initialState: BidNegotiationLoaded(
            _thread(status: 'AWAITING_PAYMENT', myTurn: false),
          ),
        );

        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(wrapPushed());
        await tester.pump(_kSettle);
        await tester.tap(find.text('Ouvrir'));
        await tester.pump(_kSettle);
        await tester.pump(_kSettle);

        paymentStates.add(
          const CheckoutPaymentSheetReady(
            clientSecret: 'pi_1_secret_2',
            publishableKey: 'pk_test_1',
            bidId: 'bid1',
            amountEur: 42,
            paymentMethodTypes: ['paypal'],
          ),
        );
        await tester.pump();
        await tester.pump(_kSettle);
        await tester.pump(_kSettle);

        // `requirePaymentAuth` a bien été traversé avant toute feuille.
        verify(() => authService.authenticateWithBiometric()).called(1);

        await tester.tap(find.byKey(const Key('paymentSheetPayPalButton')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pump(_kSettle);

        verify(
          () => bidBloc.add(
            any(
              that: isA<BidConfirmPaymentRequested>().having(
                (e) => e.bidId,
                'bidId',
                'bid1',
              ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('un refus d authentification n ouvre aucune feuille', (
      tester,
    ) async {
      when(
        () => authService.authenticateWithBiometric(),
      ).thenAnswer((_) async => false);
      when(() => authService.isPinSet()).thenAnswer((_) async => false);

      final paymentStates = StreamController<PaymentState>.broadcast();
      addTearDown(paymentStates.close);
      when(() => paymentBloc.stream).thenAnswer((_) => paymentStates.stream);
      whenListen(
        bloc,
        const Stream<BidNegotiationState>.empty(),
        initialState: BidNegotiationLoaded(
          _thread(status: 'AWAITING_PAYMENT', myTurn: false),
        ),
      );

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrapWithBloc());
      await tester.pump(_kSettle);

      // Sans PIN configuré, requirePaymentAuth laisse passer : la feuille
      // s'ouvre quand même. C'est le contrat documenté, on vérifie seulement
      // qu'on est bien passé par lui.
      paymentStates.add(
        const CheckoutPaymentSheetReady(
          clientSecret: 'pi_1_secret_2',
          publishableKey: 'pk_test_1',
          bidId: 'bid1',
          amountEur: 42,
          paymentMethodTypes: ['paypal'],
        ),
      );
      await tester.pump();
      await tester.pump(_kSettle);

      verify(() => authService.isPinSet()).called(1);
    });
  });
}
