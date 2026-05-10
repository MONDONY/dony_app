import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/services/saved_trips_service.dart';
import 'package:dony/features/matching/presentation/screens/shipment_list_screen.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class MockSavedTripsService extends Mock implements SavedTripsService {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _testUser = UserModel(
  id: 'u-1',
  phoneNumber: '+33600000001',
  roles: ['SENDER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  stripeAccountStatus: 'NOT_CREATED',
);

BidModel _makeBid({
  String id = 'bid-00000001',
  String status = 'PENDING',
}) =>
    BidModel(
      id: id,
      announcementId: 'ann-00000001',
      senderId: 'u-1',
      weightKg: 5,
      declaredValueEur: 100,
      description: 'Vêtements pour la famille',
      status: status,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
    );

// ── Constants ─────────────────────────────────────────────────────────────────

const _kSettle = Duration(milliseconds: 600);

// ── Builder ───────────────────────────────────────────────────────────────────

Widget _buildScreen({
  required MockBidBloc bidBloc,
  required MockPaymentBloc paymentBloc,
  required MockAuthBloc authBloc,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => MultiBlocProvider(
          providers: [
            BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<PaymentBloc>.value(value: paymentBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          child: const ShipmentListScreen(),
        ),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Bid detail'))),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light);
}

Future<void> _pump(
  WidgetTester tester, {
  required MockBidBloc bidBloc,
  required MockPaymentBloc paymentBloc,
  required MockAuthBloc authBloc,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _buildScreen(bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc),
  );
  await tester.pump(_kSettle);
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  late MockBidBloc bidBloc;
  late MockPaymentBloc paymentBloc;
  late MockAuthBloc authBloc;
  late MockSavedTripsService savedService;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(const BidMyListAutoRefreshRequested());
    registerFallbackValue(const AuthCheckRequested());
  });

  setUp(() {
    bidBloc = MockBidBloc();
    paymentBloc = MockPaymentBloc();
    authBloc = MockAuthBloc();
    savedService = MockSavedTripsService();

    when(() => bidBloc.state).thenReturn(BidListLoaded(const []));
    when(() => paymentBloc.state).thenReturn(const PaymentInitial());
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_testUser));
    when(() => savedService.getSavedTrips()).thenReturn([]);

    if (getIt.isRegistered<EnvoisRefreshNotifier>()) {
      getIt.unregister<EnvoisRefreshNotifier>();
    }
    getIt.registerLazySingleton<EnvoisRefreshNotifier>(EnvoisRefreshNotifier.new);

    if (getIt.isRegistered<SavedTripsService>()) {
      getIt.unregister<SavedTripsService>();
    }
    getIt.registerLazySingleton<SavedTripsService>(() => savedService);
  });

  tearDown(() {
    if (getIt.isRegistered<EnvoisRefreshNotifier>()) {
      getIt.unregister<EnvoisRefreshNotifier>();
    }
    if (getIt.isRegistered<SavedTripsService>()) {
      getIt.unregister<SavedTripsService>();
    }
  });

  // ── Smoke ─────────────────────────────────────────────────────────────────

  testWidgets('rendu sans crash (BidListLoaded vide)', (tester) async {
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    expect(find.byType(ShipmentListScreen), findsOneWidget);
  });

  // ── Aurora background ─────────────────────────────────────────────────────

  testWidgets('fond aurora : BackdropFilter présent dans le widget tree', (tester) async {
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    expect(find.byType(BackdropFilter), findsWidgets);
  });

  testWidgets('Scaffold transparent pour laisser transparaître le fond aurora', (tester) async {
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, Colors.transparent);
  });

  // ── Onglets ───────────────────────────────────────────────────────────────

  testWidgets('3 onglets visibles : En cours, À venir, Passés', (tester) async {
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('À venir'), findsOneWidget);
    expect(find.text('Passés'), findsOneWidget);
  });

  // ── État loading ──────────────────────────────────────────────────────────

  testWidgets('affiche _LoadingView quand BidLoading et pas encore de données', (tester) async {
    when(() => bidBloc.state).thenReturn(BidLoading());
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('affiche _LoadingView quand BidInitial et pas encore de données', (tester) async {
    when(() => bidBloc.state).thenReturn(BidInitial());
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // ── État erreur ───────────────────────────────────────────────────────────

  testWidgets('affiche _ErrorView quand BidError et pas encore de données', (tester) async {
    when(() => bidBloc.state).thenReturn(BidError(NetworkException('Erreur réseau')));
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    expect(find.text('Erreur réseau'), findsOneWidget);
  });

  // ── Vues vides ────────────────────────────────────────────────────────────

  testWidgets('vue vide "Aucun envoi en cours" sur onglet En cours', (tester) async {
    when(() => bidBloc.state).thenReturn(BidListLoaded(const []));
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    expect(find.text('Aucun envoi en cours'), findsOneWidget);
  });

  // ── Banner active (bid ACCEPTED) ──────────────────────────────────────────

  testWidgets('affiche la banner "COLIS EN TRANSIT" pour un bid ACCEPTED', (tester) async {
    final bid = _makeBid(status: 'ACCEPTED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    expect(find.text('COLIS EN TRANSIT'), findsOneWidget);
  });

  // ── Header stats ──────────────────────────────────────────────────────────

  testWidgets('header affiche les chips de stat (en cours / en attente)', (tester) async {
    final bids = [
      _makeBid(id: 'bid-00000001', status: 'ACCEPTED'),
      _makeBid(id: 'bid-00000002', status: 'PENDING'),
    ];
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded(bids));
    await tester.pump();
    await tester.pump(_kSettle);

    expect(find.textContaining('en cours'), findsWidgets);
  });

  // ── Titre ─────────────────────────────────────────────────────────────────

  testWidgets('titre "Mes envois" visible dans le header', (tester) async {
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    expect(find.text('Mes envois'), findsOneWidget);
  });
}
