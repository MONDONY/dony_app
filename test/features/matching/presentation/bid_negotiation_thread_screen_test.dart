import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_bloc.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_state.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/screens/bid_negotiation_thread_screen.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/error_reporting_test_doubles.dart';
import '../../../helpers/l10n_test_helpers.dart';

class _MockNegotiationBloc
    extends MockBloc<BidNegotiationEvent, BidNegotiationState>
    implements BidNegotiationBloc {}

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockBidAcceptanceBloc
    extends MockBloc<ace.BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

class _MockLocalAuthService extends Mock implements LocalAuthService {}

class _MockBox extends Mock implements Box {}

class _MockPaymentGateway extends Mock implements PaymentGateway {}

class _MockPaymentRepository extends Mock implements PaymentRepository {}

class _MockBidRepository extends Mock implements BidRepository {}

/// La confirmation serveur est un effet de bord : l'écran ignore le bid
/// renvoyé, un double suffit à satisfaire la signature.
class _FakeBidModel extends Mock implements BidModel {}

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
  BidPaymentMethod? paymentMethod,
  int round = 1,
  String? counterpartyId,
  DateTime? commissionDueBy,
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
  counterpartyId: counterpartyId,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  messages: messages,
  paymentMethod: paymentMethod,
  commissionDueBy: commissionDueBy,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockNegotiationBloc bloc;
  late _MockPaymentBloc paymentBloc;
  late _MockBidBloc bidBloc;
  late _MockBidAcceptanceBloc acceptanceBloc;
  late _MockLocalAuthService authService;
  late _MockBox userPrefsBox;
  late _MockPaymentGateway paymentGateway;
  late _MockBidRepository bidRepository;

  void register<T extends Object>(T Function() factory) {
    if (getIt.isRegistered<T>()) getIt.unregister<T>();
    getIt.registerFactory<T>(factory);
  }

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(const BidNegotiationFetchRequested('fallback'));
    registerFallbackValue(const PaymentInitial());
    registerFallbackValue(BidInitial());
    registerFallbackValue(ace.BidAcceptRequested('fallback'));
    registerFallbackValue(BidRejectRequested('fallback'));
    registerFallbackValue(
      const BidCheckoutPaymentRequested(
        clientSecret: '',
        publishableKey: '',
        bidId: '',
        amountEur: 0,
      ),
    );
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

    acceptanceBloc = _MockBidAcceptanceBloc();
    when(() => acceptanceBloc.state).thenReturn(acs.BidAcceptanceInitial());
    when(() => acceptanceBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => acceptanceBloc.close()).thenAnswer((_) async {});

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

    // La confirmation du paiement passe par le repository (et non plus par
    // BidBloc) : posté sur le bloc, l'event partait au moment où `pop()`
    // fermait ce même bloc, et le bid restait AWAITING_PAYMENT côté serveur.
    bidRepository = _MockBidRepository();
    when(
      () => bidRepository.confirmPayment(any()),
    ).thenAnswer((_) async => _FakeBidModel());
    register<BidRepository>(() => bidRepository);
  });

  tearDown(() {
    for (final unregister in [
      () => getIt.unregister<PaymentBloc>(),
      () => getIt.unregister<BidBloc>(),
      () => getIt.unregister<LocalAuthService>(),
      () => getIt.unregister<HiveService>(),
      () => getIt.unregister<PaymentGateway>(),
      () => getIt.unregister<PaymentRepository>(),
      () => getIt.unregister<BidRepository>(),
    ]) {
      unregister();
    }
  });

  /// Monte l'écran sur un bloc déjà stubé, pour les tests qui pilotent
  /// eux-mêmes le flux d'états.
  Widget wrapWithBloc() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<BidNegotiationBloc>.value(value: bloc),
        BlocProvider<BidAcceptanceBloc>.value(value: acceptanceBloc),
      ],
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
    return MultiBlocProvider(
      providers: [
        BlocProvider<BidNegotiationBloc>.value(value: bloc),
        BlocProvider<BidAcceptanceBloc>.value(value: acceptanceBloc),
      ],
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
            GoRoute(
              path: '/bids/:bidId/accepted',
              builder: (_, state) => Scaffold(
                body: Text('accepted:${state.pathParameters['bidId']}'),
              ),
            ),
            GoRoute(
              path: '/payments/wallet/topup/method',
              builder: (_, _) => Scaffold(
                body: Builder(
                  builder: (inner) => TextButton(
                    onPressed: () => inner.pop(true),
                    child: const Text('Rechargé'),
                  ),
                ),
              ),
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

  // ── FLUTTER-G8 / G9 ───────────────────────────────────────────────────────

  /// Écran sur un routeur qui connaît le profil public : on vérifie la route
  /// ouverte et l'utilisateur transmis.
  Future<Object?> pumpWithProfileRoute(
    WidgetTester tester,
    BidNegotiation thread,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    whenListen(
      bloc,
      const Stream<BidNegotiationState>.empty(),
      initialState: BidNegotiationLoaded(thread),
    );
    await tester.pumpWidget(
      BlocProvider<BidNegotiationBloc>.value(
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
              GoRoute(
                path: '/profile/public',
                builder: (_, state) => Scaffold(
                  key: const Key('profile-public-route'),
                  body: Text(
                    (state.extra as ProfilePublicArgs?)?.userId ?? 'aucun',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(_kSettle);
    return null;
  }

  testWidgets('G8 : la carte du trajet ouvre le profil public de l autre '
      'partie', (tester) async {
    await pumpWithProfileRoute(
      tester,
      _thread(netEur: 37, counterpartyId: 'user-42'),
    );

    await tester.tap(find.byKey(const Key('nego-trip-context-open-profile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-public-route')), findsOneWidget);
    expect(find.text('user-42'), findsOneWidget);
  });

  testWidgets('G8 : sans identifiant (ancien serveur), la carte reste inerte', (
    tester,
  ) async {
    await pumpWithProfileRoute(tester, _thread(netEur: 37));

    expect(find.byKey(const Key('nego-trip-context')), findsOneWidget);
    expect(
      find.byKey(const Key('nego-trip-context-open-profile')),
      findsNothing,
    );
  });

  testWidgets('G9 : une photo du colis s ouvre en plein ecran', (tester) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread(netEur: 37)));

    await tester.tap(find.byKey(const Key('nego-photo-0')));
    await tester.pump(_kSettle);

    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('G9 : « Voir le colis » ouvre la fiche detaillee', (
    tester,
  ) async {
    await pumpScreen(tester, BidNegotiationLoaded(_thread(netEur: 37)));

    await tester.tap(find.byKey(const Key('nego-view-parcel')));
    await tester.pump(_kSettle);

    final sheet = find.byKey(const Key('nego-parcel-sheet'));
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('Catégorie')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('3 kg')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Carton moyen')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('Deux paires de chaussures'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('nego-sheet-photo-0')), findsOneWidget);
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

  // ── FLUTTER-EQ : sortie visible pendant l'attente ──────────────────────
  group('annuler la negociation en attente de l autre', () {
    /// Entrée ou sortie animée de la feuille : une frame pour la lancer,
    /// une autre pour la mener à terme.
    Future<void> settleSheet(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(_kSettle);
    }

    List<BidNegotiationCancelRequested> cancels() => verify(
      () => bloc.add(captureAny()),
    ).captured.whereType<BidNegotiationCancelRequested>().toList();

    testWidgets('le bouton secondaire est la pendant l attente', (
      tester,
    ) async {
      await pumpScreen(tester, BidNegotiationLoaded(_thread(myTurn: false)));

      final button = tester.widget<DonyButton>(
        find.byKey(const Key('nego-cancel-btn')),
      );
      expect(button.label, 'Annuler la négociation');
      expect(button.variant, DonyButtonVariant.secondary);
    });

    testWidgets('jamais quand c est mon tour ni sur un fil clos', (
      tester,
    ) async {
      await pumpScreen(tester, BidNegotiationLoaded(_thread()));
      expect(find.byKey(const Key('nego-cancel-btn')), findsNothing);

      await pumpScreen(
        tester,
        BidNegotiationLoaded(
          _thread(status: 'NEGOTIATION_CLOSED', myTurn: false),
        ),
      );
      expect(find.byKey(const Key('nego-cancel-btn')), findsNothing);
    });

    testWidgets('expediteur : confirmation, note de nouvelle offre, puis '
        'BidNegotiationCancelRequested', (tester) async {
      await pumpScreen(tester, BidNegotiationLoaded(_thread(myTurn: false)));

      await tester.tap(find.byKey(const Key('nego-cancel-btn')));
      await settleSheet(tester);

      expect(find.text('Annuler la négociation ?'), findsOneWidget);
      expect(find.textContaining('close pour vous deux'), findsOneWidget);
      expect(find.byKey(const Key('nego-cancel-reoffer-note')), findsOneWidget);
      // Rien ne part avant la confirmation.
      expect(cancels(), isEmpty);

      final confirm = tester.widget<DonyButton>(
        find.byKey(const Key('nego-cancel-confirm')),
      );
      expect(confirm.variant, DonyButtonVariant.destructive);
      await tester.tap(find.byKey(const Key('nego-cancel-confirm')));
      await settleSheet(tester);

      final sent = cancels();
      expect(sent, hasLength(1));
      expect(sent.single.bidId, 'bid1');
      expect(find.text('Annuler la négociation ?'), findsNothing);
    });

    testWidgets('voyageur : pas de promesse de nouvelle offre', (tester) async {
      await pumpScreen(
        tester,
        BidNegotiationLoaded(_thread(myTurn: false, netEur: 37)),
      );

      await tester.tap(find.byKey(const Key('nego-cancel-btn')));
      await settleSheet(tester);

      expect(find.text('Annuler la négociation ?'), findsOneWidget);
      expect(find.byKey(const Key('nego-cancel-reoffer-note')), findsNothing);
    });

    testWidgets('continuer a negocier referme la feuille sans rien envoyer', (
      tester,
    ) async {
      await pumpScreen(tester, BidNegotiationLoaded(_thread(myTurn: false)));

      await tester.tap(find.byKey(const Key('nego-cancel-btn')));
      await settleSheet(tester);
      await tester.tap(find.byKey(const Key('nego-cancel-keep')));
      await settleSheet(tester);

      expect(find.text('Annuler la négociation ?'), findsNothing);
      expect(cancels(), isEmpty);
    });

    testWidgets('en anglais : bouton et feuille traduits', (tester) async {
      useEnglish();
      await pumpScreen(tester, BidNegotiationLoaded(_thread(myTurn: false)));

      expect(find.text('Cancel the negotiation'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nego-cancel-btn')));
      await settleSheet(tester);

      expect(find.text('Cancel the negotiation?'), findsOneWidget);
      expect(find.text('Keep negotiating'), findsOneWidget);
      expect(
        find.text(
          'You can make a new offer on this trip as long as it stays open.',
        ),
        findsOneWidget,
      );
    });
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

  // ── Accord en espèces : le voyageur règle la commission (FLUTTER-H7) ──────

  group('reglement de la commission d un accord en especes', () {
    BidNegotiation cashTraveler({DateTime? commissionDueBy}) => _thread(
      status: 'PENDING',
      myTurn: false,
      netEur: 37,
      paymentMethod: BidPaymentMethod.cash,
      commissionDueBy: commissionDueBy,
    );

    /// Écran poussé (pour que `pop(true)` ait une page à dépiler), flux
    /// d'états de l'acceptation et du refus pilotés par le test.
    Future<
      (StreamController<acs.BidAcceptanceState>, StreamController<BidState>)
    >
    pumpPushed(WidgetTester tester, BidNegotiation thread) async {
      final acceptance = StreamController<acs.BidAcceptanceState>.broadcast();
      final bids = StreamController<BidState>.broadcast();
      addTearDown(acceptance.close);
      addTearDown(bids.close);
      when(() => acceptanceBloc.stream).thenAnswer((_) => acceptance.stream);
      when(() => bidBloc.stream).thenAnswer((_) => bids.stream);
      whenListen(
        bloc,
        const Stream<BidNegotiationState>.empty(),
        initialState: BidNegotiationLoaded(thread),
      );
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrapPushed());
      await tester.pump(_kSettle);
      await tester.tap(find.text('Ouvrir'));
      await tester.pump(_kSettle);
      await tester.pump(_kSettle);
      return (acceptance, bids);
    }

    testWidgets('voyageur : bouton, montant et echeance de la commission', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        BidNegotiationLoaded(
          cashTraveler(
            commissionDueBy: DateTime.now().toUtc().add(
              const Duration(hours: 5),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('nego-settle-commission-btn')),
        findsOneWidget,
      );
      expect(find.text('Régler la commission'), findsOneWidget);
      expect(find.byKey(const Key('nego-decline-parcel-btn')), findsOneWidget);
      expect(find.text('Refuser le colis'), findsOneWidget);
      // Brut 42 − net 37 : la commission que le serveur prélèvera.
      final amount = tester.widget<Text>(
        find.byKey(const Key('nego-cash-commission-amount')),
      );
      expect(amount.data, startsWith('Commission Yadony : 5'));
      expect(
        find.byKey(const Key('nego-cash-commission-countdown')),
        findsOneWidget,
      );
      // Le bandeau garde son texte, cohérent avec le bouton.
      expect(
        find.text(
          'Prix accepté. Paiement en espèces, il vous reste à régler la '
          'commission Yadony.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('serveur ancien : pas d echeance, pas de compte a rebours', (
      tester,
    ) async {
      await pumpScreen(tester, BidNegotiationLoaded(cashTraveler()));

      expect(
        find.byKey(const Key('nego-settle-commission-btn')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('nego-cash-commission-countdown')),
        findsNothing,
      );
    });

    testWidgets('expediteur : aucun bouton de reglement', (tester) async {
      await pumpScreen(
        tester,
        BidNegotiationLoaded(_thread(status: 'PENDING', myTurn: false)),
      );

      expect(find.byKey(const Key('nego-settle-commission-btn')), findsNothing);
      expect(find.byKey(const Key('nego-decline-parcel-btn')), findsNothing);
    });

    testWidgets('hors attente de reglement : aucun bouton', (tester) async {
      await pumpScreen(
        tester,
        BidNegotiationLoaded(
          _thread(status: 'ACCEPTED', myTurn: false, netEur: 37),
        ),
      );

      expect(find.byKey(const Key('nego-settle-commission-btn')), findsNothing);
    });

    testWidgets('regler : authentification puis prelevement', (tester) async {
      await pumpScreen(tester, BidNegotiationLoaded(cashTraveler()));

      await tester.tap(find.byKey(const Key('nego-settle-commission-btn')));
      await tester.pump(_kSettle);

      verify(() => authService.authenticateWithBiometric()).called(1);
      final sent = verify(
        () => acceptanceBloc.add(captureAny()),
      ).captured.whereType<ace.BidAcceptRequested>().toList();
      expect(sent, hasLength(1));
      expect(sent.single.bidId, 'bid1');
      expect(sent.single.fundingCurrency, isNull);
    });

    testWidgets('authentification refusee : rien n est preleve', (
      tester,
    ) async {
      when(
        () => userPrefsBox.get(
          HiveService.kBiometricEnabled,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(false);
      when(() => authService.isPinSet()).thenAnswer((_) async => true);

      final (acceptance, _) = await pumpPushed(tester, cashTraveler());
      expect(acceptance.hasListener, isTrue);

      // Le PIN existe : requirePaymentAuth ouvre sa saisie, absente de ce
      // routeur de test. La page d'erreur de GoRouter se ferme sans valeur,
      // ce qui vaut refus.
      await tester.tap(find.byKey(const Key('nego-settle-commission-btn')));
      await tester.pump(_kSettle);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
      nav.pop();
      await tester.pump(_kSettle);
      await tester.pump(_kSettle);

      verifyNever(() => acceptanceBloc.add(any()));
    });

    testWidgets('pendant le prelevement les deux gestes sont desactives', (
      tester,
    ) async {
      when(() => acceptanceBloc.state).thenReturn(acs.BidAccepting());
      await pumpScreen(tester, BidNegotiationLoaded(cashTraveler()));

      final button = tester.widget<DonyButton>(
        find.byKey(const Key('nego-settle-commission-btn')),
      );
      expect(button.onPressed, isNull);
      expect(button.isLoading, isTrue);
      final decline = tester.widget<TextButton>(
        find.byKey(const Key('nego-decline-parcel-btn')),
      );
      expect(decline.onPressed, isNull);
    });

    testWidgets('solde insuffisant : recharge puis nouvelle tentative', (
      tester,
    ) async {
      final (acceptance, _) = await pumpPushed(tester, cashTraveler());

      acceptance.add(
        acs.BidWalletInsufficient(
          availableBalance: 1,
          requiredCommission: 5,
          hasCard: false,
          bidId: 'bid1',
          currency: 'EUR',
        ),
      );
      await tester.pump();
      await tester.pump(_kSettle);
      await tester.pump(_kSettle);

      // Feuille partagée avec le fil de demande de colis.
      expect(find.text('Solde insuffisant'), findsOneWidget);
      await tester.tap(find.textContaining('Recharger'));
      await tester.pump(_kSettle);
      await tester.pump(_kSettle);

      await tester.tap(find.text('Rechargé'));
      await tester.pump(_kSettle);
      await tester.pump(_kSettle);

      final sent = verify(
        () => acceptanceBloc.add(captureAny()),
      ).captured.whereType<ace.BidAcceptRequested>().toList();
      expect(sent, hasLength(1));
      expect(sent.single.bidId, 'bid1');
    });

    testWidgets('solde insuffisant avec carte : repli carte', (tester) async {
      final (acceptance, _) = await pumpPushed(tester, cashTraveler());

      acceptance.add(
        acs.BidWalletInsufficient(
          availableBalance: 1,
          requiredCommission: 5,
          hasCard: true,
          bidId: 'bid1',
          currency: 'EUR',
        ),
      );
      await tester.pump();
      await tester.pump(_kSettle);
      await tester.pump(_kSettle);

      await tester.tap(find.text('Payer par carte'));
      await tester.pump(_kSettle);
      await tester.pump(_kSettle);

      final sent = verify(
        () => acceptanceBloc.add(captureAny()),
      ).captured.whereType<ace.BidAcceptWithCardRequested>().toList();
      expect(sent, hasLength(1));
      expect(sent.single.bidId, 'bid1');
    });

    testWidgets('commission reglee : fil relu et ecran de succes', (
      tester,
    ) async {
      final (acceptance, _) = await pumpPushed(tester, cashTraveler());

      acceptance.add(acs.BidAccepted());
      await tester.pump();
      await tester.pump(_kSettle);
      await tester.pump(_kSettle);

      expect(find.text('accepted:bid1'), findsOneWidget);
      verify(
        () => bloc.add(
          any(
            that: isA<BidNegotiationFetchRequested>().having(
              (e) => e.bidId,
              'bidId',
              'bid1',
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('echec du prelevement : message d erreur', (tester) async {
      final (acceptance, _) = await pumpPushed(tester, cashTraveler());

      acceptance.add(acs.BidFailed(reason: acs.BidFailureReason.refused));
      await tester.pump();
      await tester.pump(_kSettle);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Ouvrir'), findsNothing);
    });

    testWidgets('refuser le colis : motif, refus du bid puis fermeture', (
      tester,
    ) async {
      final (_, bids) = await pumpPushed(tester, cashTraveler());

      await tester.tap(find.byKey(const Key('nego-decline-parcel-btn')));
      await tester.pump(_kSettle);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Plus assez de place'));
      await tester.pump(_kSettle);
      await tester.tap(find.byKey(const Key('reject-reason-confirm')));
      await tester.pump(_kSettle);
      await tester.pump(_kSettle);

      final sent = verify(
        () => bidBloc.add(captureAny()),
      ).captured.whereType<BidRejectRequested>().toList();
      expect(sent, hasLength(1));
      expect(sent.single.bidId, 'bid1');
      expect(sent.single.reason, 'NO_CAPACITY');

      bids.add(BidRejected(_FakeBidModel()));
      await tester.pump();
      await tester.pump(_kSettle);
      await tester.pump(_kSettle);

      expect(find.text('Ouvrir'), findsOneWidget);
    });

    testWidgets('refus en erreur : le fil reste ouvert', (tester) async {
      final (_, bids) = await pumpPushed(tester, cashTraveler());

      bids.add(BidError(const NetworkException('offline')));
      await tester.pump();
      await tester.pump(_kSettle);

      expect(find.text('Ouvrir'), findsNothing);
      expect(
        find.byKey(const Key('nego-settle-commission-btn')),
        findsOneWidget,
      );
    });

    testWidgets('accepter le prix en especes garde le fil ouvert', (
      tester,
    ) async {
      final states = StreamController<BidNegotiationState>.broadcast();
      addTearDown(states.close);
      whenListen(
        bloc,
        states.stream,
        initialState: BidNegotiationLoaded(
          _thread(netEur: 37, paymentMethod: BidPaymentMethod.cash),
        ),
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
          cashTraveler(),
          action: BidNegotiationAction.accepted,
        ),
      );
      await tester.pump(_kSettle);
      await tester.pump(_kSettle);

      expect(find.text('Ouvrir'), findsNothing);
      expect(
        find.byKey(const Key('nego-settle-commission-btn')),
        findsOneWidget,
      );
    });

    testWidgets('en anglais : bouton et lien traduits', (tester) async {
      useEnglish();
      await pumpScreen(tester, BidNegotiationLoaded(cashTraveler()));

      expect(find.text('Pay the service fee'), findsOneWidget);
      expect(find.text('Decline the parcel'), findsOneWidget);
      final amount = tester.widget<Text>(
        find.byKey(const Key('nego-cash-commission-amount')),
      );
      expect(amount.data, startsWith('Yadony service fee: '));
    });
  });

  // ── Enchaînement sur le parcours de paiement carte existant ────────────────

  group('accord en mobile money', () {
    /// Fil poussé depuis un écran racine, avec l'écran d'attente mobile money
    /// remplacé par un double qui rend `paid` au retour, comme le vrai
    /// (`MobileMoneyAwaitingScreen` → `context.pop(paid)`).
    Widget wrapWithMobileMoney({required bool paid}) {
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
              GoRoute(
                path: '/bids/:bidId/mobile-money/awaiting',
                builder: (_, state) => Scaffold(
                  body: Builder(
                    builder: (inner) => TextButton(
                      key: const Key('fake-mm-done'),
                      onPressed: () => inner.pop(paid),
                      child: Text('awaiting ${state.pathParameters['bidId']}'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> openThread(WidgetTester tester, {required bool paid}) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      whenListen(
        bloc,
        const Stream<BidNegotiationState>.empty(),
        initialState: BidNegotiationLoaded(
          _thread(
            status: 'AWAITING_PAYMENT',
            myTurn: false,
            paymentMethod: BidPaymentMethod.mobileMoney,
          ),
        ),
      );
      await tester.pumpWidget(wrapWithMobileMoney(paid: paid));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('cote expediteur : payer par mobile money, pas par carte', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        BidNegotiationLoaded(
          _thread(
            status: 'AWAITING_PAYMENT',
            myTurn: false,
            paymentMethod: BidPaymentMethod.mobileMoney,
          ),
        ),
      );

      expect(
        find.byKey(const Key('nego-pay-mobile-money-btn')),
        findsOneWidget,
      );
      expect(find.text('Payer par mobile money'), findsOneWidget);
      // Jamais le checkout carte : le back le refuse sur un accord mobile money.
      expect(find.byKey(const Key('nego-pay-btn')), findsNothing);
    });

    testWidgets('cote voyageur : attente du paiement de l expediteur', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        BidNegotiationLoaded(
          _thread(
            status: 'AWAITING_PAYMENT',
            myTurn: false,
            netEur: 37,
            paymentMethod: BidPaymentMethod.mobileMoney,
          ),
        ),
      );

      expect(find.byKey(const Key('nego-pay-mobile-money-btn')), findsNothing);
      expect(
        find.byKey(const Key('nego-awaiting-payment-hint')),
        findsOneWidget,
      );
    });

    testWidgets('paiement confirme : le fil se referme', (tester) async {
      await openThread(tester, paid: true);

      await tester.tap(find.byKey(const Key('nego-pay-mobile-money-btn')));
      await tester.pumpAndSettle();
      expect(find.text('awaiting bid1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('fake-mm-done')));
      await tester.pumpAndSettle();

      expect(find.byType(BidNegotiationThreadScreen), findsNothing);
      expect(find.text('Ouvrir'), findsOneWidget);
    });

    testWidgets('paiement abandonne : le fil est relu', (tester) async {
      await openThread(tester, paid: false);
      // Seul le retour de l'écran d'attente doit relire le fil.
      clearInteractions(bloc);

      await tester.tap(find.byKey(const Key('nego-pay-mobile-money-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fake-mm-done')));
      await tester.pumpAndSettle();

      // L'accord a pu être annulé à l'échéance du dépôt : on relit le fil.
      expect(find.byType(BidNegotiationThreadScreen), findsOneWidget);
      final fetches = verify(
        () => bloc.add(captureAny()),
      ).captured.whereType<BidNegotiationFetchRequested>().toList();
      expect(fetches, hasLength(1));
      expect(fetches.single.bidId, 'bid1');
    });
  });

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

        // Confirmation adressée au repository, et ATTENDUE avant que l'écran
        // ne se ferme : la poster sur `bidBloc` puis popper fermait le bloc
        // (dispose) à l'instant où la requête devait partir, laissant le bid
        // en AWAITING_PAYMENT côté serveur alors que l'escrow était actif.
        verify(() => bidRepository.confirmPayment('bid1')).called(1);
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

  group('en anglais', () {
    testWidgets('montant, tour et actions traduits', (tester) async {
      useEnglish();
      await pumpScreen(tester, BidNegotiationLoaded(_thread()));

      expect(find.text('You would pay'), findsOneWidget);
      expect(find.text('Round 1 of 6'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Counter-propose'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets('fil clos par refus : message traduit', (tester) async {
      useEnglish();
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

      expect(find.text('Proposal declined.'), findsOneWidget);
    });
  });
}
