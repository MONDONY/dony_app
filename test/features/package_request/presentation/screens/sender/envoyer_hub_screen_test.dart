import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
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
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/bloc/request_filter_cubit.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

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

// ── Helpers ───────────────────────────────────────────────────────────────────

void _unregisterIfPresent<T extends Object>() {
  if (getIt.isRegistered<T>()) {
    getIt.unregister<T>();
  }
}

NegotiationThread _stubThread(NegotiationThreadStatus status) => NegotiationThread(
      id: 't-${status.name}',
      packageRequestId: 'pr-1',
      travelerId: 'traveler-001',
      currentPriceEur: 15,
      roundsCount: 1,
      travelerAvailableKg: 10,
      travelerTravelDate: DateTime(2026, 8, 1),
      lastActivityAt: DateTime(2026, 6, 1),
      createdAt: DateTime(2026, 6, 1),
      status: status,
      messages: const [],
    );

PackageRequest _sampleRequest() => PackageRequest(
      id: 'pr-test',
      senderId: 's-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 8, 15),
      dateToleranceDays: 2,
      weightKg: 5,
      parcelSize: ParcelSize.medium,
      transportMode: TransportMode.plane,
      contentCategory: ContentCategory.vetements,
      status: PackageRequestStatus.open,
      createdAt: DateTime(2026, 6, 1),
    );

void main() {
  late _MockPackageRequestBloc packageBloc;
  late _MockBidBloc bidBloc;
  late _MockNegotiationListBloc negoListBloc;
  late _MockPaymentBloc paymentBloc;
  late _MockAnalyticsService analytics;

  setUpAll(() async {
    await initializeDateFormatting('fr', null);
    registerFallbackValue(const FetchMyRequests());
    registerFallbackValue(const RefreshMyRequests());
    registerFallbackValue(const BidMyListAutoRefreshRequested());
    registerFallbackValue(const NegotiationListFetchRequested());
    registerFallbackValue(const NegotiationListRefreshRequested());
  });

  setUp(() {
    packageBloc = _MockPackageRequestBloc();
    bidBloc = _MockBidBloc();
    negoListBloc = _MockNegotiationListBloc();
    paymentBloc = _MockPaymentBloc();
    analytics = _MockAnalyticsService();

    // Stub bloc states — provide a loaded request so the search bar is visible
    // in the Demandes tab (the search field only renders when requests is non-empty).
    when(() => packageBloc.state).thenReturn(PackageRequestState(
      status: PackageRequestListStatus.loaded,
      requests: [_sampleRequest()],
    ));
    when(() => packageBloc.stream)
        .thenAnswer((_) => const Stream<PackageRequestState>.empty());

    whenListen<BidState>(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: BidListLoaded([]),
    );

    when(() => negoListBloc.state).thenReturn(NegotiationListState());
    when(() => negoListBloc.stream)
        .thenAnswer((_) => const Stream<NegotiationListState>.empty());

    whenListen<PaymentState>(
      paymentBloc,
      const Stream<PaymentState>.empty(),
      initialState: const PaymentInitial(),
    );

    // Stub analytics
    when(() => analytics.logScreen(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});
    when(() => analytics.logEvent(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});

    // Register blocs in getIt
    _unregisterIfPresent<PackageRequestBloc>();
    _unregisterIfPresent<BidBloc>();
    _unregisterIfPresent<NegotiationListBloc>();
    _unregisterIfPresent<AnalyticsService>();
    _unregisterIfPresent<ShipmentFilterCubit>();
    _unregisterIfPresent<RequestFilterCubit>();
    _unregisterIfPresent<NegotiationFilterCubit>();
    _unregisterIfPresent<EnvoisRefreshNotifier>();

    getIt.registerFactory<PackageRequestBloc>(() => packageBloc);
    getIt.registerFactory<BidBloc>(() => bidBloc);
    getIt.registerFactory<NegotiationListBloc>(() => negoListBloc);
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
    getIt.registerFactory<ShipmentFilterCubit>(() => ShipmentFilterCubit(analytics));
    getIt.registerFactory<RequestFilterCubit>(() => RequestFilterCubit());
    getIt.registerFactory<NegotiationFilterCubit>(() => NegotiationFilterCubit());
    getIt.registerLazySingleton<EnvoisRefreshNotifier>(() => EnvoisRefreshNotifier());
  });

  tearDown(() async {
    _unregisterIfPresent<PackageRequestBloc>();
    _unregisterIfPresent<BidBloc>();
    _unregisterIfPresent<NegotiationListBloc>();
    _unregisterIfPresent<AnalyticsService>();
    _unregisterIfPresent<ShipmentFilterCubit>();
    _unregisterIfPresent<RequestFilterCubit>();
    _unregisterIfPresent<NegotiationFilterCubit>();
    _unregisterIfPresent<EnvoisRefreshNotifier>();
  });

  Widget wrap({String kycStatus = 'VERIFIED'}) {
    final authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(
      AuthAuthenticated(
        UserModel(
          id: 'u1',
          roles: const ['SENDER'],
          kycStatus: kycStatus,
          status: 'ACTIVE',
        ),
      ),
    );
    when(() => authBloc.stream)
        .thenAnswer((_) => const Stream<AuthState>.empty());

    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<PaymentBloc>.value(value: paymentBloc),
        ],
        child: const EnvoyerHubScreen(),
      ),
    );
  }

  group('EnvoyerHubScreen — 2 onglets', () {
    testWidgets(
        'les 2 labels de segments sont présents (Envois, Demandes), plus de Négos',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Envois'), findsWidgets);
      expect(find.textContaining('Demandes'), findsWidgets);
      // L'onglet Négos a été fusionné dans Demandes (offres visibles dans le détail).
      expect(find.textContaining('Négos'), findsNothing);
    });

    testWidgets(
        'au chargement le premier onglet (Envois / ShipmentListBody) est affiché',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      // ShipmentListBody is shown (Envois tab active) — when bid list is empty
      // the new DonyEmptyState displays "Aucun envoi pour l'instant".
      // The Demandes hint ('Ville, catégorie…') is NOT visible yet.
      expect(find.textContaining('Aucun envoi'), findsOneWidget);
      expect(find.text('Ville, catégorie…'), findsNothing);
    });

    testWidgets(
        'taper sur "Demandes" affiche MyPackageRequestsBody avec son hint',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      // Tap the Demandes segment (tab index 1)
      await tester.tap(find.textContaining('Demandes').first);
      // Drive the TabBarView animation + debounce timers to completion
      await tester.pumpAndSettle();

      expect(find.text('Ville, catégorie…'), findsOneWidget);
    });

    testWidgets(
        'changer d\'onglet déclenche le refresh du bloc correspondant',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      // → onglet Demandes (index 1) : rafraîchit les demandes ET les négos
      // (les offres reçues y sont désormais surfacées).
      await tester.tap(find.textContaining('Demandes').first);
      await tester.pumpAndSettle();
      verify(() => packageBloc.add(const RefreshMyRequests())).called(1);
      verify(() => negoListBloc.add(const NegotiationListRefreshRequested()))
          .called(1);

      // → retour onglet Envois (index 0) : BidMyListAutoRefreshRequested envoyé
      await tester.tap(find.textContaining('Envois').first);
      await tester.pumpAndSettle();
      verify(() => bidBloc.add(const BidMyListAutoRefreshRequested())).called(greaterThanOrEqualTo(1));
    });

    testWidgets(
        'pas de badge sur Demandes avant la première visite (lastSeen=-1)',
        (tester) async {
      // 2 négos actives, mais l'onglet Demandes n'a pas encore été visité.
      when(() => negoListBloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [
            _stubThread(NegotiationThreadStatus.open),
            _stubThread(NegotiationThreadStatus.awaitingTrip),
          ],
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      // _lastSeenNegoThreads == -1 → badge = 0, aucun badge rouge visible.
      expect(find.text('2'), findsNothing);
    });

    testWidgets('le bouton "+ Nouveau" est présent (HeaderPill)', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('+ Nouveau'), findsOneWidget);
    });

    testWidgets(
        'HeaderPill "Mes trajets" absent quand onShowTrips == null',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('show-trips-pill')), findsNothing);
    });

    testWidgets(
        'HeaderPill "Mes trajets" présent quand onShowTrips != null',
        (tester) async {
      final authBloc = _MockAuthBloc();
      when(() => authBloc.state).thenReturn(
        AuthAuthenticated(
          UserModel(
            id: 'u1',
            roles: const ['SENDER'],
            kycStatus: 'VERIFIED',
            status: 'ACTIVE',
          ),
        ),
      );
      when(() => authBloc.stream)
          .thenAnswer((_) => const Stream<AuthState>.empty());

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<PaymentBloc>.value(value: paymentBloc),
            ],
            child: EnvoyerHubScreen(onShowTrips: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('show-trips-pill')), findsOneWidget);
    });

    testWidgets(
        'sliding capsule segmented control présent avec labels Envois et Demandes',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      // Both segment labels visible
      expect(find.textContaining('Envois'), findsWidgets);
      expect(find.textContaining('Demandes'), findsWidgets);
    });

    testWidgets(
        'tapper Demandes déplace le segment et affiche le contenu Demandes',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.textContaining('Demandes').first);
      await tester.pumpAndSettle();

      // After switching to Demandes tab, should show demandes search hint
      expect(find.text('Ville, catégorie…'), findsOneWidget);
    });

    testWidgets(
        'tap sur "Mes trajets" pill appelle onShowTrips',
        (tester) async {
      var called = false;
      final authBloc = _MockAuthBloc();
      when(() => authBloc.state).thenReturn(
        AuthAuthenticated(
          UserModel(
            id: 'u1',
            roles: const ['SENDER'],
            kycStatus: 'VERIFIED',
            status: 'ACTIVE',
          ),
        ),
      );
      when(() => authBloc.stream)
          .thenAnswer((_) => const Stream<AuthState>.empty());

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<PaymentBloc>.value(value: paymentBloc),
            ],
            child: EnvoyerHubScreen(onShowTrips: () => called = true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(const Key('show-trips-pill')));
      await tester.pump();

      expect(called, isTrue);
    });
  });

  // ── Badge logic ───────────────────────────────────────────────────────────────

  group('EnvoyerHubScreen — badge logic', () {
    testWidgets(
        'badge Envois affiché quand BidListLoaded avec bids AWAITING_PAYMENT arrivant via stream',
        (tester) async {
      // Start with empty bid list
      final bidStreamController = StreamController<BidState>.broadcast();
      whenListen<BidState>(
        bidBloc,
        bidStreamController.stream,
        initialState: BidListLoaded([]),
      );

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      // Switch to Demandes to make Envois "not active" (so badge can show)
      await tester.tap(find.textContaining('Demandes').first);
      await tester.pumpAndSettle();

      // Now emit a bid list with an AWAITING_PAYMENT bid
      // First mark seen so _lastSeen[0] = 0
      // Then update to have 1 bid → badge = 1
      final bidWithPayment = BidModel(
        id: 'bid-1',
        announcementId: 'ann-1',
        senderId: 's-1',
        status: 'AWAITING_PAYMENT',
        senderKycVerified: false,
        senderIsProAccount: false,
        senderKiloPro: false,
        travelerKycVerified: false,
        travelerIsProAccount: false,
        travelerKiloPro: false,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      bidStreamController.add(BidListLoaded([bidWithPayment]));
      await tester.pump(const Duration(milliseconds: 400));

      // Badge "1" should appear on Envois tab
      expect(find.text('1'), findsWidgets);

      await bidStreamController.close();
    });

    testWidgets(
        '_negoBadge = 0 when currently on Demandes tab (index 1)',
        (tester) async {
      when(() => negoListBloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [_stubThread(NegotiationThreadStatus.open)],
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      // Switch to Demandes — badge should be 0 (we're on that tab)
      await tester.tap(find.textContaining('Demandes').first);
      await tester.pumpAndSettle();

      // No badge indicator for Demandes tab when it's active
      // The _SegLabel for Demandes should not show a badge container
      expect(find.text('1'), findsNothing);
    });

    testWidgets(
        '_markSeen(1) executes when NegotiationListBloc emits loaded on Demandes tab',
        (tester) async {
      final negoStreamController = StreamController<NegotiationListState>.broadcast();
      when(() => negoListBloc.stream).thenAnswer((_) => negoStreamController.stream);

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      // Navigate to Demandes tab
      await tester.tap(find.textContaining('Demandes').first);
      await tester.pumpAndSettle();

      // Emit loaded state — this exercises BlocListener for NegotiationListBloc
      // and calls _markSeen(1) since _controller.index == 1
      negoStreamController.add(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [_stubThread(NegotiationThreadStatus.open)],
      ));
      await tester.pump(const Duration(milliseconds: 400));

      // No badge should show since we're currently on the Demandes tab
      expect(find.text('Ville, catégorie…'), findsOneWidget);

      await negoStreamController.close();
    });

    testWidgets(
        '_markSeen(0) executes when BidBloc emits BidListLoaded on Envois tab',
        (tester) async {
      final bidStreamController = StreamController<BidState>.broadcast();
      whenListen<BidState>(
        bidBloc,
        bidStreamController.stream,
        initialState: BidListLoaded([]),
      );

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      // Emit BidListLoaded on Envois tab (index 0) — exercises BlocListener path
      bidStreamController.add(BidListLoaded([]));
      await tester.pump(const Duration(milliseconds: 400));

      // No exception, Envois tab still shown
      expect(find.textContaining('Aucun envoi'), findsOneWidget);

      await bidStreamController.close();
    });

    testWidgets(
        '_markSeen(1) via PackageRequestBloc listener on Demandes tab',
        (tester) async {
      final pkgStreamController = StreamController<PackageRequestState>.broadcast();
      when(() => packageBloc.stream).thenAnswer((_) => pkgStreamController.stream);

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      // Switch to Demandes
      await tester.tap(find.textContaining('Demandes').first);
      await tester.pumpAndSettle();

      // Emit loaded state — exercises PackageRequestBloc BlocListener
      pkgStreamController.add(PackageRequestState(
        status: PackageRequestListStatus.loaded,
        requests: [_sampleRequest()],
      ));
      await tester.pump(const Duration(milliseconds: 400));

      // Screen still works correctly
      expect(find.text('Ville, catégorie…'), findsOneWidget);

      await pkgStreamController.close();
    });
  });

  // ── In-app nego notifications (_onNegoStateChanged) ──────────────────────────

  group('EnvoyerHubScreen — _onNegoStateChanged notifications', () {
    testWidgets(
        'nouvelle négociation → snackbar avec message offre reçue (onglet Envois actif)',
        (tester) async {
      final negoStreamController = StreamController<NegotiationListState>.broadcast();
      // Start with empty threads so the initial state is "no threads"
      when(() => negoListBloc.state).thenReturn(NegotiationListState());
      when(() => negoListBloc.stream).thenAnswer((_) => negoStreamController.stream);

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      final initialThread = NegotiationThread(
        id: 'prev-t1',
        packageRequestId: 'pr-1',
        travelerId: 'traveler-001',
        travelerName: 'Ibrahima',
        currentPriceEur: 15,
        grossPriceEur: 17,
        roundsCount: 1,
        travelerAvailableKg: 10,
        travelerTravelDate: DateTime(2026, 8, 1),
        lastActivityAt: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1),
        status: NegotiationThreadStatus.open,
        messages: const [],
      );

      // First emission: sets _prevNegoState (prev == null → returns early, sets _prevNegoState)
      negoStreamController.add(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [initialThread],
      ));
      await tester.pump(const Duration(milliseconds: 400));

      // Now emit with a NEW thread → should trigger snackbar notification
      // _prevNegoState.threads.isNotEmpty = true, so notification fires
      final newThread = NegotiationThread(
        id: 'new-t2',
        packageRequestId: 'pr-2',
        travelerId: 'traveler-002',
        travelerName: 'Moussa',
        currentPriceEur: 20,
        grossPriceEur: 22,
        roundsCount: 1,
        travelerAvailableKg: 8,
        travelerTravelDate: DateTime(2026, 9, 1),
        lastActivityAt: DateTime(2026, 6, 15),
        createdAt: DateTime(2026, 6, 15),
        status: NegotiationThreadStatus.open,
        messages: const [],
      );
      negoStreamController.add(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [initialThread, newThread],
      ));
      await tester.pump(const Duration(milliseconds: 400));

      // A snackbar with the new offer notification should appear
      expect(find.textContaining('Moussa'), findsWidgets);

      await negoStreamController.close();
    });

    testWidgets(
        'counter-proposal detected → snackbar (roundsCount increased, status open)',
        (tester) async {
      final negoStreamController = StreamController<NegotiationListState>.broadcast();
      // Start with empty threads so listenWhen fires on first emission
      when(() => negoListBloc.state).thenReturn(NegotiationListState());
      when(() => negoListBloc.stream).thenAnswer((_) => negoStreamController.stream);

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      final thread1 = NegotiationThread(
        id: 't1',
        packageRequestId: 'pr-1',
        travelerId: 'traveler-001',
        travelerName: 'Ibrahima',
        currentPriceEur: 15,
        grossPriceEur: 17,
        roundsCount: 1,
        travelerAvailableKg: 10,
        travelerTravelDate: DateTime(2026, 8, 1),
        lastActivityAt: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1),
        status: NegotiationThreadStatus.open,
        messages: const [],
      );

      // First emission: _prevNegoState = null → sets _prevNegoState = {[thread1]}
      negoStreamController.add(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [thread1],
      ));
      await tester.pump(const Duration(milliseconds: 400));

      // Counter-proposal: same thread id but roundsCount increased
      final thread1Updated = NegotiationThread(
        id: 't1',
        packageRequestId: 'pr-1',
        travelerId: 'traveler-001',
        travelerName: 'Ibrahima',
        currentPriceEur: 18,
        grossPriceEur: 20,
        roundsCount: 2, // increased!
        travelerAvailableKg: 10,
        travelerTravelDate: DateTime(2026, 8, 1),
        lastActivityAt: DateTime(2026, 6, 10),
        createdAt: DateTime(2026, 6, 1),
        status: NegotiationThreadStatus.open,
        messages: const [],
      );
      negoStreamController.add(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [thread1Updated],
      ));
      await tester.pump(const Duration(milliseconds: 400));

      // Snackbar for counter-proposal should appear
      expect(find.textContaining('contre-proposition'), findsWidgets);

      await negoStreamController.close();
    });

    testWidgets(
        'proposition acceptée → snackbar succès (status changes to accepted)',
        (tester) async {
      final negoStreamController = StreamController<NegotiationListState>.broadcast();
      // Start with empty threads so listenWhen fires on first emission
      when(() => negoListBloc.state).thenReturn(NegotiationListState());
      when(() => negoListBloc.stream).thenAnswer((_) => negoStreamController.stream);

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      final thread1 = NegotiationThread(
        id: 't1',
        packageRequestId: 'pr-1',
        travelerId: 'traveler-001',
        travelerName: 'Ibrahima',
        currentPriceEur: 15,
        grossPriceEur: 17,
        roundsCount: 2,
        travelerAvailableKg: 10,
        travelerTravelDate: DateTime(2026, 8, 1),
        lastActivityAt: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1),
        status: NegotiationThreadStatus.open,
        messages: const [],
      );

      // First emission: sets _prevNegoState = {[thread1]}
      negoStreamController.add(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [thread1],
      ));
      await tester.pump(const Duration(milliseconds: 400));

      // Thread accepted — status changes from open to accepted
      final thread1Accepted = NegotiationThread(
        id: 't1',
        packageRequestId: 'pr-1',
        travelerId: 'traveler-001',
        travelerName: 'Ibrahima',
        currentPriceEur: 15,
        grossPriceEur: 17,
        roundsCount: 2,
        travelerAvailableKg: 10,
        travelerTravelDate: DateTime(2026, 8, 1),
        lastActivityAt: DateTime(2026, 6, 15),
        createdAt: DateTime(2026, 6, 1),
        status: NegotiationThreadStatus.accepted, // changed!
        messages: const [],
      );
      negoStreamController.add(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [thread1Accepted],
      ));
      await tester.pump(const Duration(milliseconds: 400));

      // Success snackbar for accepted proposition
      expect(find.textContaining('accepté'), findsWidgets);

      await negoStreamController.close();
    });

    testWidgets(
        'no notification when _prevNegoState is null (first load)',
        (tester) async {
      final negoStreamController = StreamController<NegotiationListState>.broadcast();
      when(() => negoListBloc.stream).thenAnswer((_) => negoStreamController.stream);

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      // First emission — _prevNegoState is null, no notification shown
      final thread = _stubThread(NegotiationThreadStatus.open);
      negoStreamController.add(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [thread],
      ));
      await tester.pump(const Duration(milliseconds: 400));

      // No snackbar
      expect(find.byType(SnackBar), findsNothing);

      await negoStreamController.close();
    });

    testWidgets(
        'no notification when on Demandes tab (user already sees changes)',
        (tester) async {
      final negoStreamController = StreamController<NegotiationListState>.broadcast();
      // Start with empty threads so listenWhen fires on first emission
      when(() => negoListBloc.state).thenReturn(NegotiationListState());
      when(() => negoListBloc.stream).thenAnswer((_) => negoStreamController.stream);

      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 400));

      final thread1 = NegotiationThread(
        id: 't1',
        packageRequestId: 'pr-1',
        travelerId: 'traveler-001',
        travelerName: 'Ibrahima',
        currentPriceEur: 15,
        grossPriceEur: 17,
        roundsCount: 1,
        travelerAvailableKg: 10,
        travelerTravelDate: DateTime(2026, 8, 1),
        lastActivityAt: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1),
        status: NegotiationThreadStatus.open,
        messages: const [],
      );

      // First emission to set _prevNegoState
      negoStreamController.add(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [thread1],
      ));
      await tester.pump(const Duration(milliseconds: 400));

      // Switch to Demandes tab
      await tester.tap(find.textContaining('Demandes').first);
      await tester.pumpAndSettle();

      // Add a new thread while on Demandes tab — no snackbar expected
      final thread2 = NegotiationThread(
        id: 't2',
        packageRequestId: 'pr-2',
        travelerId: 'traveler-002',
        travelerName: 'Moussa',
        currentPriceEur: 25,
        grossPriceEur: 28,
        roundsCount: 1,
        travelerAvailableKg: 5,
        travelerTravelDate: DateTime(2026, 9, 1),
        lastActivityAt: DateTime(2026, 6, 20),
        createdAt: DateTime(2026, 6, 20),
        status: NegotiationThreadStatus.open,
        messages: const [],
      );
      negoStreamController.add(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [thread1, thread2],
      ));
      await tester.pump(const Duration(milliseconds: 400));

      // No snackbar since user is on Demandes tab
      expect(find.byType(SnackBar), findsNothing);

      await negoStreamController.close();
    });
  });
}
