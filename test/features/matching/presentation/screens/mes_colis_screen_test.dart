import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/screens/mes_colis_screen.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/bloc/request_filter_cubit.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockPackageRequestBloc
    extends MockBloc<PackageRequestEvent, PackageRequestState>
    implements PackageRequestBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockNegotiationListBloc
    extends MockBloc<NegotiationListEvent, NegotiationListState>
    implements NegotiationListBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void _unregisterIfPresent<T extends Object>() {
  if (getIt.isRegistered<T>()) {
    getIt.unregister<T>();
  }
}

PackageRequest _request(PackageRequestStatus status, {String id = 'pr-1'}) =>
    PackageRequest(
      id: id,
      senderId: 's-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 8, 15),
      dateToleranceDays: 2,
      weightKg: 5,
      parcelSize: ParcelSize.medium,
      transportMode: TransportMode.plane,
      categories: const ['Vêtements'],
      status: status,
      createdAt: DateTime(2026, 6),
    );

NegotiationThread _thread({
  required String requestId,
  bool hasUnread = false,
  String id = 'th-1',
}) => NegotiationThread(
  id: id,
  packageRequestId: requestId,
  travelerId: 'tr-1',
  status: NegotiationThreadStatus.open,
  currentPriceEur: 45,
  roundsCount: 1,
  lastActivityAt: DateTime(2026, 6, 10),
  createdAt: DateTime(2026, 6),
  travelerTravelDate: DateTime(2026, 7),
  travelerAvailableKg: 10,
  messages: const [],
  hasUnread: hasUnread,
);

void main() {
  late _MockPackageRequestBloc packageBloc;
  late _MockBidBloc bidBloc;
  late _MockNegotiationListBloc negoListBloc;
  late _MockPaymentBloc paymentBloc;
  late _MockAnalyticsService analytics;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(const FetchMyRequests());
    registerFallbackValue(const BidMyListAutoRefreshRequested());
    registerFallbackValue(const NegotiationListRefreshRequested());
  });

  setUp(() {
    packageBloc = _MockPackageRequestBloc();
    bidBloc = _MockBidBloc();
    negoListBloc = _MockNegotiationListBloc();
    paymentBloc = _MockPaymentBloc();
    analytics = _MockAnalyticsService();

    when(() => packageBloc.state).thenReturn(PackageRequestState());
    when(
      () => packageBloc.stream,
    ).thenAnswer((_) => const Stream<PackageRequestState>.empty());

    whenListen<BidState>(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: BidListLoaded(const []),
    );

    when(() => negoListBloc.state).thenReturn(NegotiationListState());
    when(
      () => negoListBloc.stream,
    ).thenAnswer((_) => const Stream<NegotiationListState>.empty());

    whenListen<PaymentState>(
      paymentBloc,
      const Stream<PaymentState>.empty(),
      initialState: const PaymentInitial(),
    );

    when(
      () => analytics.logScreen(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    _unregisterIfPresent<AnalyticsService>();
    _unregisterIfPresent<ShipmentFilterCubit>();
    _unregisterIfPresent<RequestFilterCubit>();
    _unregisterIfPresent<EnvoisRefreshNotifier>();

    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
    getIt.registerFactory<ShipmentFilterCubit>(
      () => ShipmentFilterCubit(analytics),
    );
    getIt.registerFactory<RequestFilterCubit>(() => RequestFilterCubit());
    getIt.registerLazySingleton<EnvoisRefreshNotifier>(
      () => EnvoisRefreshNotifier(),
    );
  });

  tearDown(() {
    _unregisterIfPresent<AnalyticsService>();
    _unregisterIfPresent<ShipmentFilterCubit>();
    _unregisterIfPresent<RequestFilterCubit>();
    _unregisterIfPresent<EnvoisRefreshNotifier>();
  });

  Future<void> pump(
    WidgetTester tester, {
    MesColisTab initialTab = MesColisTab.enRoute,
    PackageRequestState? packageState,
    NegotiationListState? negoState,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    if (packageState != null) {
      when(() => packageBloc.state).thenReturn(packageState);
    }
    if (negoState != null) {
      when(() => negoListBloc.state).thenReturn(negoState);
    }

    final authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(
      const AuthAuthenticated(
        UserModel(
          id: 'u1',
          roles: ['SENDER'],
          kycStatus: 'VERIFIED',
          status: 'ACTIVE',
        ),
      ),
    );
    when(
      () => authBloc.stream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<BidBloc>.value(value: bidBloc),
              BlocProvider<PackageRequestBloc>.value(value: packageBloc),
              BlocProvider<NegotiationListBloc>.value(value: negoListBloc),
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<PaymentBloc>.value(value: paymentBloc),
            ],
            child: MesColisScreenTesting(initialTab: initialTab),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    );
    // Draine les timers d'animation (flutter_animate dans les listes vides).
    await tester.pump(const Duration(seconds: 1));
  }

  int? bodyIndex(WidgetTester tester) =>
      tester.widget<IndexedStack>(find.byKey(const Key('mes-colis-body'))).index;

  group('MesColisScreen — chrome', () {
    testWidgets('affiche le titre « Mes colis » et la pill « Envoyer »', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Mes colis'), findsOneWidget);
      expect(find.byKey(const Key('mes-colis-new-request')), findsOneWidget);
    });

    testWidgets('affiche les deux volets En route / Publiés', (tester) async {
      await pump(tester);

      expect(find.byKey(const Key('mes-colis-tab-en-route')), findsOneWidget);
      expect(find.byKey(const Key('mes-colis-tab-publies')), findsOneWidget);
      expect(find.text('En route'), findsOneWidget);
      expect(find.text('Publiés'), findsOneWidget);
    });
  });

  group('MesColisScreen — volets', () {
    testWidgets('ouvre « En route » par défaut', (tester) async {
      await pump(tester);

      expect(bodyIndex(tester), MesColisTab.enRoute.index);
    });

    testWidgets('initialTab permet de viser « Publiés »', (tester) async {
      await pump(tester, initialTab: MesColisTab.publies);

      expect(bodyIndex(tester), MesColisTab.publies.index);
    });

    testWidgets('le tap sur « Publiés » bascule de volet', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const Key('mes-colis-tab-publies')));
      await tester.pump(const Duration(seconds: 1));

      expect(bodyIndex(tester), MesColisTab.publies.index);
    });

    testWidgets('charge les demandes publiées à l’ouverture', (tester) async {
      await pump(tester);

      verify(() => packageBloc.add(const FetchMyRequests())).called(1);
    });
  });

  group('MesColisScreen — badge du volet Publiés', () {
    Finder badge() => find.descendant(
      of: find.byKey(const Key('mes-colis-tab-publies')),
      matching: find.text('1'),
    );

    testWidgets('une discussion non lue affiche le badge', (tester) async {
      await pump(
        tester,
        packageState: PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [_request(PackageRequestStatus.negotiating)],
        ),
        negoState: NegotiationListState(
          threads: [_thread(requestId: 'pr-1', hasUnread: true)],
        ),
      );

      expect(badge(), findsOneWidget);
    });

    testWidgets('une discussion déjà lue n’affiche pas de badge', (
      tester,
    ) async {
      // Le badge est un signal d'attention : une négociation en cours mais
      // déjà lue ne doit pas l'allumer en permanence.
      await pump(
        tester,
        packageState: PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [_request(PackageRequestStatus.negotiating)],
        ),
        negoState: NegotiationListState(
          threads: [_thread(requestId: 'pr-1')],
        ),
      );

      expect(badge(), findsNothing);
    });

    testWidgets('une discussion non lue sur la demande d’un autre est ignorée', (
      tester,
    ) async {
      await pump(
        tester,
        packageState: PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [_request(PackageRequestStatus.open)],
        ),
        negoState: NegotiationListState(
          threads: [_thread(requestId: 'pr-autre', hasUnread: true)],
        ),
      );

      expect(badge(), findsNothing);
    });

    testWidgets('charge la liste des discussions à l’ouverture', (tester) async {
      await pump(tester);

      verify(
        () => negoListBloc.add(const NegotiationListRefreshRequested()),
      ).called(1);
    });
  });

  group('compteurs de colis publiés', () {
    PackageRequestState stateWith(List<PackageRequestStatus> statuses) =>
        PackageRequestState(
          status: PackageRequestListStatus.loaded,
          requests: [
            for (var i = 0; i < statuses.length; i++)
              _request(statuses[i], id: 'pr-$i'),
          ],
        );

    test('colisPublies ne compte que OPEN et NEGOTIATING', () {
      final state = stateWith([
        PackageRequestStatus.open,
        PackageRequestStatus.negotiating,
        PackageRequestStatus.draft,
        PackageRequestStatus.expired,
        PackageRequestStatus.cancelled,
        PackageRequestStatus.accepted,
        PackageRequestStatus.completed,
      ]);

      expect(colisPublies(state), 2);
    });

    test('negosNonLuesSurMesColis ne compte que les fils non lus des miennes', () {
      final requests = PackageRequestState(
        requests: [_request(PackageRequestStatus.open, id: 'pr-0')],
      );
      final negos = NegotiationListState(
        threads: [
          _thread(requestId: 'pr-0', hasUnread: true, id: 'th-a'),
          // Déjà lu → pas un signal d'attention.
          _thread(requestId: 'pr-0', id: 'th-b'),
          // Non lu, mais sur la demande de quelqu'un d'autre.
          _thread(requestId: 'pr-inconnue', hasUnread: true, id: 'th-c'),
        ],
      );

      expect(negosNonLuesSurMesColis(requests, negos), 1);
    });

    test('les deux compteurs valent zéro sur un état vide', () {
      expect(colisPublies(PackageRequestState()), 0);
      expect(
        negosNonLuesSurMesColis(PackageRequestState(), NegotiationListState()),
        0,
      );
    });
  });
}
