import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
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

// ── Fixture ───────────────────────────────────────────────────────────────────

const _testUser = UserModel(
  id: 'u-1',
  phoneNumber: '+33600000001',
  roles: ['SENDER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  stripeAccountStatus: 'NOT_CREATED',
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

Future<void> _pumpScreen(
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

  setUpAll(() {
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
    getIt.registerLazySingleton<EnvoisRefreshNotifier>(
      () => EnvoisRefreshNotifier(),
    );

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

  // ── Smoke test ────────────────────────────────────────────────────────────

  testWidgets('ShipmentListScreen — rendu sans crash', (tester) async {
    await _pumpScreen(
      tester,
      bidBloc: bidBloc,
      paymentBloc: paymentBloc,
      authBloc: authBloc,
    );

    expect(find.byType(ShipmentListScreen), findsOneWidget);
  });

  // ── Aurora background ─────────────────────────────────────────────────────

  testWidgets('ShipmentListScreen — fond aurora : BackdropFilter présent', (tester) async {
    await _pumpScreen(
      tester,
      bidBloc: bidBloc,
      paymentBloc: paymentBloc,
      authBloc: authBloc,
    );

    // Le fond Aurora et les composants glass utilisent BackdropFilter
    expect(find.byType(BackdropFilter), findsWidgets);
  });

  testWidgets('ShipmentListScreen — Scaffold transparent (fond aurora visible)', (tester) async {
    await _pumpScreen(
      tester,
      bidBloc: bidBloc,
      paymentBloc: paymentBloc,
      authBloc: authBloc,
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, Colors.transparent);
  });

  // ── Onglets ───────────────────────────────────────────────────────────────

  testWidgets('ShipmentListScreen — 3 onglets visibles', (tester) async {
    await _pumpScreen(
      tester,
      bidBloc: bidBloc,
      paymentBloc: paymentBloc,
      authBloc: authBloc,
    );

    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('À venir'), findsOneWidget);
    expect(find.text('Passés'), findsOneWidget);
  });

  // ── Vue vide ──────────────────────────────────────────────────────────────

  testWidgets('ShipmentListScreen — vue vide affichée quand liste est vide', (tester) async {
    when(() => bidBloc.state).thenReturn(BidListLoaded(const []));

    await _pumpScreen(
      tester,
      bidBloc: bidBloc,
      paymentBloc: paymentBloc,
      authBloc: authBloc,
    );

    expect(find.text('Aucun envoi en cours'), findsOneWidget);
  });
}
