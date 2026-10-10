import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/traveler_bids_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_event.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/demandes_screen.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_analytics_backend.dart';

class _MockTravelerBidsBloc
    extends MockBloc<TravelerBidsEvent, TravelerBidsState>
    implements TravelerBidsBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockBidAcceptanceBloc
    extends MockBloc<ace.BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {
  /// Refus définitifs simulés (trajet complet…), vides par défaut.
  Map<String, AppException> refusalsValue = const {};

  @override
  Map<String, AppException> get refusals => refusalsValue;
}

class _MockPackageRequestBloc
    extends MockBloc<PackageRequestEvent, PackageRequestState>
    implements PackageRequestBloc {}

class _MockNegotiationListBloc
    extends MockBloc<NegotiationListEvent, NegotiationListState>
    implements NegotiationListBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

BidModel _bid(
  String id,
  String status, {
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
}) => BidModel(
  id: id,
  announcementId: 'a1',
  senderId: 's1',
  weightKg: 5,
  status: status,
  paymentMethod: paymentMethod,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

// ContextualTutorialCard (contexte receivedRequests) lit HelpCenterBloc via
// context.select : sans ce provider, context.select lève
// ProviderNotFoundException dès le premier pump.
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

late List<String> visited;

Future<_MockPackageRequestBloc> _pump(
  WidgetTester tester, {
  required TravelerBidsState travelerBidsState,
  _MockBidBloc? bidBloc,
  _MockBidAcceptanceBloc? acceptanceBloc,
  String? focusBidId,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  visited = [];

  final travelerBids = _MockTravelerBidsBloc();
  when(() => travelerBids.state).thenReturn(travelerBidsState);
  // Un rechargement qui attend sa réponse (`done`) la reçoit tout de suite.
  when(() => travelerBids.add(any())).thenAnswer((invocation) {
    final event = invocation.positionalArguments.first;
    if (event is TravelerBidsRequested) event.done?.complete(null);
  });
  // Réutilise les mocks fournis par l'appelant (nécessaire pour vérifier les
  // events dispatchés, ex. tap Accepter) sinon en crée de nouveaux avec un
  // état par défaut neutre.
  final resolvedBidBloc = bidBloc ?? _MockBidBloc();
  when(() => resolvedBidBloc.state).thenReturn(BidListLoaded(const []));
  final resolvedAcceptance = acceptanceBloc ?? _MockBidAcceptanceBloc();
  when(() => resolvedAcceptance.state).thenReturn(acs.BidAcceptanceInitial());
  final packageRequests = _MockPackageRequestBloc();
  when(() => packageRequests.state).thenReturn(PackageRequestState());
  final negotiations = _MockNegotiationListBloc();
  when(() => negotiations.state).thenReturn(NegotiationListState());

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<TravelerBidsBloc>.value(value: travelerBids),
            BlocProvider<BidBloc>.value(value: resolvedBidBloc),
            BlocProvider<BidAcceptanceBloc>.value(value: resolvedAcceptance),
            BlocProvider<PackageRequestBloc>.value(value: packageRequests),
            BlocProvider<NegotiationListBloc>.value(value: negotiations),
            BlocProvider<HelpCenterBloc>(
              create: (_) => HelpCenterBloc(
                HelpCenterRepository(
                  const _StaticHelpCenterSource(_emptyHelpConfigJson),
                  fallbackJsonLoader: () async => _emptyHelpConfigJson,
                ),
                makeDisabledAnalytics(MockAnalyticsBackend()),
              )..add(const HelpCenterLoadRequested()),
            ),
          ],
          child: DemandesScreenTesting(focusBidId: focusBidId),
        ),
      ),
      GoRoute(
        path: '/bids/:bidId',
        builder: (_, state) {
          visited.add('/bids/${state.pathParameters['bidId']}');
          return const Scaffold(body: Text('Détail demande'));
        },
      ),
      GoRoute(
        path: '/trips/create',
        builder: (_, _) {
          visited.add('/trips/create');
          return const Scaffold(body: Text('Créer trajet'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
  );
  // Draine les timers d'animation (flutter_animate dans l'empty state / les
  // cartes) : sans ça le binding échoue sur un timer encore en vol.
  await tester.pump(const Duration(seconds: 1));
  return packageRequests;
}

void main() {
  setUpAll(() {
    registerFallbackValue(const TravelerBidsRequested());
    registerFallbackValue(BidAcceptRequested('fallback'));
    registerFallbackValue(BidAcceptMobileMoneyRequested('fallback'));
    registerFallbackValue(ace.BidAcceptRequested('fallback'));
  });

  setUp(() {
    if (!getIt.isRegistered<AnalyticsService>()) {
      final analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerLazySingleton<AnalyticsService>(() => analytics);
    }
  });

  tearDown(() => getIt.reset());

  TravelerBidsLoaded loaded(List<BidModel> bids) => TravelerBidsLoaded(
    bids: bids,
    page: 0,
    hasMore: false,
    filter: TravelerBidFilter.aTraiter,
  );

  testWidgets('l’écran est mono-rôle : plus de toggle Reçues / Envoyées', (
    tester,
  ) async {
    await _pump(tester, travelerBidsState: loaded(const []));

    expect(find.text('Reçues'), findsNothing);
    expect(find.text('Envoyées'), findsNothing);
  });

  testWidgets('ne charge plus les demandes envoyées', (tester) async {
    // Le volet « Envoyées » vit désormais dans « Mes colis » (/envois) : cet
    // écran ne doit plus toucher au bloc des demandes publiées.
    final packageRequests = await _pump(
      tester,
      travelerBidsState: loaded(const []),
    );

    verifyNever(() => packageRequests.add(const RefreshMyRequests()));
    verifyNever(() => packageRequests.add(const FetchMyRequests()));
  });

  testWidgets('le décompte « à traiter » vit sur la pastille de filtre', (
    tester,
  ) async {
    await _pump(
      tester,
      travelerBidsState: loaded([
        _bid('b1', 'PENDING'),
        _bid('b2', 'PAYMENT_ESCROWED'),
        _bid('b3', 'ACCEPTED'),
      ]),
    );

    // 2 en attente d'une décision (PENDING + PAYMENT_ESCROWED), pas le 3e.
    // Sans toggle, c'est la pastille de filtre qui porte le compteur.
    expect(find.text('À traiter (2)'), findsOneWidget);
  });

  testWidgets('la pastille affiche zéro quand rien n’est à traiter', (
    tester,
  ) async {
    await _pump(tester, travelerBidsState: loaded([_bid('b1', 'ACCEPTED')]));

    expect(find.text('À traiter (0)'), findsOneWidget);
  });

  testWidgets('l\'état vide « À traiter » propose de publier un trajet', (
    tester,
  ) async {
    await _pump(tester, travelerBidsState: loaded(const []));

    final cta = find.text('Publier un trajet');
    expect(cta, findsOneWidget);

    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(visited, contains('/trips/create'));
  });

  testWidgets('le volet Reçues propose un champ de recherche', (tester) async {
    await _pump(tester, travelerBidsState: loaded([_bid('b1', 'PENDING')]));

    expect(
      find.widgetWithText(TextField, 'Expéditeur, n° de suivi…'),
      findsOneWidget,
    );
  });

  // ── Accepter — dispatch selon mode de paiement ──────────────────────────────

  testWidgets(
    'tap Accepter sur bid CASH → BidAcceptanceBloc.add(BidAcceptRequested)',
    (tester) async {
      final bidBloc = _MockBidBloc();
      final acceptance = _MockBidAcceptanceBloc();

      await _pump(
        tester,
        travelerBidsState: loaded([
          _bid(
            'cash-1',
            'PAYMENT_ESCROWED',
            paymentMethod: BidPaymentMethod.cash,
          ),
        ]),
        bidBloc: bidBloc,
        acceptanceBloc: acceptance,
      );

      await tester.tap(find.text('Accepter'));
      await tester.pump();

      verify(
        () => acceptance.add(any(that: isA<ace.BidAcceptRequested>())),
      ).called(1);
      verifyNever(() => bidBloc.add(any()));
    },
  );

  testWidgets(
    'demande refusée pour de bon (capacity-insufficient) : raison affichée, '
    'Accepter désactivé, aucun nouvel envoi',
    (tester) async {
      final acceptance = _MockBidAcceptanceBloc()
        ..refusalsValue = {
          'cash-1': const ConflictException('x', code: 'capacity-insufficient'),
        };

      await _pump(
        tester,
        travelerBidsState: loaded([
          _bid('cash-1', 'PENDING', paymentMethod: BidPaymentMethod.cash),
        ]),
        acceptanceBloc: acceptance,
      );

      expect(
        find.textContaining('ne suffisent plus pour ce colis'),
        findsOneWidget,
      );
      await tester.tap(find.text('Accepter'));
      await tester.pump();
      verifyNever(() => acceptance.add(any()));
    },
  );

  testWidgets(
    'refus définitif reçu : message précis en snackbar et liste rechargée',
    (tester) async {
      final acceptance = _MockBidAcceptanceBloc();
      whenListen(
        acceptance,
        Stream<acs.BidAcceptanceState>.fromIterable([
          acs.BidFailed(
            reason: acs.BidFailureReason.refused,
            error: const ConflictException('x', code: 'capacity-insufficient'),
            bidId: 'cash-1',
            definitive: true,
          ),
        ]),
        initialState: acs.BidAcceptanceInitial(),
      );

      await _pump(
        tester,
        travelerBidsState: loaded([
          _bid('cash-1', 'PENDING', paymentMethod: BidPaymentMethod.cash),
        ]),
        acceptanceBloc: acceptance,
      );
      await tester.pump();

      expect(find.text('Acceptation refusée'), findsNothing);
      expect(
        find.textContaining('ne suffisent plus pour ce colis'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tap Accepter sur bid MOBILE_MONEY → BidBloc.add(BidAcceptMobileMoneyRequested)',
    (tester) async {
      final bidBloc = _MockBidBloc();
      final acceptance = _MockBidAcceptanceBloc();

      await _pump(
        tester,
        travelerBidsState: loaded([
          _bid(
            'mm-1',
            'PAYMENT_ESCROWED',
            paymentMethod: BidPaymentMethod.mobileMoney,
          ),
        ]),
        bidBloc: bidBloc,
        acceptanceBloc: acceptance,
      );

      await tester.tap(find.text('Accepter'));
      await tester.pump();

      verify(
        () => bidBloc.add(any(that: isA<BidAcceptMobileMoneyRequested>())),
      ).called(1);
      verifyNever(() => acceptance.add(any()));
    },
  );

  testWidgets(
    'demande acceptée : la liste est rechargée et le serveur fait foi '
    '(FLUTTER-B9)',
    (tester) async {
      final bidBloc = _MockBidBloc();
      final accepted = _bid('mm-1', 'AWAITING_PAYMENT');
      whenListen(
        bidBloc,
        Stream<BidState>.fromIterable([BidAccepted(accepted)]),
        initialState: BidListLoaded(const []),
      );

      await _pump(
        tester,
        travelerBidsState: loaded([_bid('mm-1', 'PAYMENT_ESCROWED')]),
        bidBloc: bidBloc,
      );
      final travelerBids = BlocProvider.of<TravelerBidsBloc>(
        tester.element(find.byType(DemandesScreenTesting)),
      );
      await tester.pumpAndSettle();

      final captured = verify(() => travelerBids.add(captureAny())).captured;
      final reloads = captured.whereType<TravelerBidsRequested>().where(
        (e) => e.force && e.done != null,
      );
      expect(reloads, isNotEmpty);
    },
  );

  group('ouverture depuis la notification « Nouvelle demande d\'envoi »', () {
    const focus = 'b1b2c3d4-e5f6-7890-abcd-ef1234567890';

    testWidgets('ouvre la demande par-dessus la liste', (tester) async {
      await _pump(
        tester,
        travelerBidsState: loaded([_bid(focus, 'PENDING')]),
        focusBidId: focus,
      );
      await tester.pumpAndSettle();

      expect(visited, ['/bids/$focus']);
    });

    testWidgets('au retour du détail, la liste est rechargée', (tester) async {
      await _pump(
        tester,
        travelerBidsState: loaded([_bid(focus, 'PENDING')]),
        focusBidId: focus,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Détail demande'));
      // La liste est hors scène sous le détail poussé par-dessus.
      final travelerBids = BlocProvider.of<TravelerBidsBloc>(
        tester.element(find.byType(DemandesScreenTesting, skipOffstage: false)),
      );
      clearInteractions(travelerBids);
      GoRouter.of(context).pop();
      await tester.pumpAndSettle();

      verify(
        () => travelerBids.add(const TravelerBidsRequested(force: true)),
      ).called(1);
    });

    testWidgets('un id non UUID n\'ouvre rien', (tester) async {
      await _pump(
        tester,
        travelerBidsState: loaded(const []),
        focusBidId: '../../admin',
      );
      await tester.pumpAndSettle();

      expect(visited, isEmpty);
    });

    testWidgets('sans demande ciblée, rien ne s\'ouvre', (tester) async {
      await _pump(tester, travelerBidsState: loaded(const []));
      await tester.pumpAndSettle();

      expect(visited, isEmpty);
    });

    test('validFocusBidId ne garde que les UUID', () {
      expect(validFocusBidId(focus), focus);
      expect(validFocusBidId(focus.toUpperCase()), focus.toUpperCase());
      expect(validFocusBidId(null), isNull);
      expect(validFocusBidId(''), isNull);
      expect(validFocusBidId('b1'), isNull);
      expect(validFocusBidId('$focus/../x'), isNull);
    });

    testWidgets('l\'écran réel force le filtre « À traiter »', (tester) async {
      // Le bloc est un singleton qui garde le dernier filtre : venu d'une
      // notification, une nouvelle demande ne doit pas tomber sous
      // « Terminées ».
      final travelerBids = _MockTravelerBidsBloc();
      when(() => travelerBids.state).thenReturn(
        TravelerBidsLoaded(
          bids: const [],
          page: 0,
          hasMore: false,
          filter: TravelerBidFilter.terminees,
        ),
      );
      final bidBloc = _MockBidBloc();
      when(() => bidBloc.state).thenReturn(BidListLoaded(const []));
      final acceptance = _MockBidAcceptanceBloc();
      when(() => acceptance.state).thenReturn(acs.BidAcceptanceInitial());
      getIt
        ..registerSingleton<TravelerBidsBloc>(travelerBids)
        ..registerFactory<BidBloc>(() => bidBloc)
        ..registerFactory<BidAcceptanceBloc>(() => acceptance);

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
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => const DemandesScreen(focusBidId: focus),
                ),
                GoRoute(
                  path: '/bids/:bidId',
                  builder: (_, _) => const Scaffold(body: Text('Détail')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      verify(
        () => travelerBids.add(
          const TravelerBidsFilterChanged(TravelerBidFilter.aTraiter),
        ),
      ).called(1);
      // Et recharge : la demande de la notification est peut-être plus
      // récente que la liste gardée en mémoire par le singleton.
      verify(
        () => travelerBids.add(const TravelerBidsRequested(force: true)),
      ).called(1);
      expect(find.text('Détail'), findsOneWidget);
    });
  });

  group('traductions', () {
    testWidgets('en anglais : titre + chips de filtre traduits', (
      tester,
    ) async {
      useEnglish();
      await _pump(
        tester,
        travelerBidsState: loaded([
          _bid('b1', 'PENDING'),
          _bid('b2', 'ACCEPTED'),
        ]),
      );

      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('To review (1)'), findsOneWidget);
      expect(find.text('Accepted (1)'), findsOneWidget);
      expect(find.text('Completed (0)'), findsOneWidget);
      expect(find.text('Demandes'), findsNothing);
    });
  });
}
