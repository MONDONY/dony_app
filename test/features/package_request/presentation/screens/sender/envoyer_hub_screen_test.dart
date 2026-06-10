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
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/bloc/request_filter_cubit.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
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
  });
}
