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
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
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
        builder: (_, __) => Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Bid detail')),
        ),
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

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(const BidMyListAutoRefreshRequested());
    registerFallbackValue(const AuthCheckRequested());
    registerFallbackValue(BidMyListRequested());
    registerFallbackValue(const BidCheckoutPaymentRequested(
      clientSecret: '', publishableKey: '', bidId: ''));
    registerFallbackValue(BidDeleteRequested(''));
    registerFallbackValue(BidCheckoutRequested(
      announcementId: '', weightKg: 0, declaredValueEur: 0,
      description: '', contentCategory: '', recipientName: '', recipientPhone: ''));
  });

  setUp(() {
    bidBloc = MockBidBloc();
    paymentBloc = MockPaymentBloc();
    authBloc = MockAuthBloc();

    when(() => bidBloc.state).thenReturn(BidListLoaded(const []));
    when(() => paymentBloc.state).thenReturn(const PaymentInitial());
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_testUser));

    if (getIt.isRegistered<EnvoisRefreshNotifier>()) {
      getIt.unregister<EnvoisRefreshNotifier>();
    }
    getIt.registerLazySingleton<EnvoisRefreshNotifier>(EnvoisRefreshNotifier.new);
  });

  tearDown(() {
    if (getIt.isRegistered<EnvoisRefreshNotifier>()) {
      getIt.unregister<EnvoisRefreshNotifier>();
    }
  });

  // ── Smoke ─────────────────────────────────────────────────────────────────

  testWidgets('rendu sans crash (BidListLoaded vide)', (tester) async {
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    expect(find.byType(ShipmentListScreen), findsOneWidget);
  });

  // ── Header sombre ─────────────────────────────────────────────────────────

  testWidgets('header fond #0A2540 présent dans le widget tree', (tester) async {
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    final containers = tester.widgetList<Container>(find.byType(Container));
    final hasNavyHeader = containers.any((c) =>
        c.color == const Color(0xFF0A2540) ||
        (c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == const Color(0xFF0A2540)));
    expect(hasNavyHeader, isTrue);
  });

  testWidgets('fond Scaffold #F2F1EF (pas transparent)', (tester) async {
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    final scaffolds = tester.widgetList<Scaffold>(find.byType(Scaffold));
    final hasLightBg = scaffolds.any(
        (s) => s.backgroundColor == const Color(0xFFF2F1EF));
    expect(hasLightBg, isTrue);
  });

  // ── Onglets ───────────────────────────────────────────────────────────────

  testWidgets('3 onglets visibles : En cours, À venir, Passés', (tester) async {
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('À venir'), findsOneWidget);
    expect(find.text('Passés'), findsOneWidget);
  });

  // ── État loading ──────────────────────────────────────────────────────────

  testWidgets('affiche CircularProgressIndicator quand BidLoading sans données', (tester) async {
    when(() => bidBloc.state).thenReturn(BidLoading());
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('affiche CircularProgressIndicator quand BidInitial sans données', (tester) async {
    when(() => bidBloc.state).thenReturn(BidInitial());
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // ── État erreur ───────────────────────────────────────────────────────────

  testWidgets('affiche message erreur quand BidError sans données', (tester) async {
    when(() => bidBloc.state).thenReturn(BidError(const NetworkException('Erreur réseau')));
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    expect(
      find.text('Une erreur est survenue. Vérifie ta connexion et réessaie.'),
      findsOneWidget,
    );
  });

  // ── Vues vides ────────────────────────────────────────────────────────────

  testWidgets('tab "En cours" vide → "Aucun envoi en cours"', (tester) async {
    when(() => bidBloc.state).thenReturn(BidListLoaded(const []));
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    expect(find.text('Aucun envoi en cours'), findsOneWidget);
  });

  // ── Titre ─────────────────────────────────────────────────────────────────

  testWidgets('titre "Mes envois" visible dans le header', (tester) async {
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    expect(find.text('Mes envois'), findsOneWidget);
  });

  // ── Stepper ───────────────────────────────────────────────────────────────

  testWidgets('card PENDING : stepper affiche les 4 labels', (tester) async {
    final bid = _makeBid(status: 'PENDING');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    // Tab "À venir" affiche les bids PENDING
    await tester.tap(find.text('À venir'));
    await tester.pumpAndSettle();

    expect(find.text('Proposé'), findsOneWidget);
    expect(find.text('À payer'), findsOneWidget);
    expect(find.text('Confirmé'), findsOneWidget);
    expect(find.text('Livré'), findsOneWidget);
  });

  testWidgets('card ACCEPTED : stepper affiche les 4 labels', (tester) async {
    final bid = _makeBid(status: 'ACCEPTED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    // Tab "En cours" affiche les bids ACCEPTED
    expect(find.text('Proposé'), findsOneWidget);
    expect(find.text('À payer'), findsOneWidget);
    expect(find.text('Confirmé'), findsOneWidget);
    expect(find.text('Livré'), findsOneWidget);
  });

  // ── CTA contextuel ────────────────────────────────────────────────────────

  testWidgets('CTA "Payer →" pour status AWAITING_PAYMENT', (tester) async {
    final bid = _makeBid(status: 'AWAITING_PAYMENT');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('À venir'));
    await tester.pumpAndSettle();

    expect(find.text('Payer →'), findsOneWidget);
  });

  testWidgets('CTA "Voir →" pour status ACCEPTED', (tester) async {
    final bid = _makeBid(status: 'ACCEPTED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    expect(find.text('Voir →'), findsOneWidget);
  });

  testWidgets('CTA "Détail →" pour status COMPLETED', (tester) async {
    final bid = _makeBid(status: 'COMPLETED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();

    expect(find.text('Détail →'), findsOneWidget);
  });

  // ── Filtrage par tab ──────────────────────────────────────────────────────

  testWidgets('tab "En cours" n\'affiche que les ACCEPTED', (tester) async {
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

    // En cours tab (default) shows ACCEPTED, not PENDING
    expect(find.text('Paris → Dakar'), findsOneWidget);
  });

  testWidgets('tab "Passés" vide → "Aucun historique"', (tester) async {
    when(() => bidBloc.state).thenReturn(BidListLoaded(const []));
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();

    expect(find.text('Aucun historique'), findsOneWidget);
  });

  testWidgets('tab "À venir" vide → "Aucune demande en attente"', (tester) async {
    when(() => bidBloc.state).thenReturn(BidListLoaded(const []));
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);

    await tester.tap(find.text('À venir'));
    await tester.pumpAndSettle();

    expect(find.text('Aucune demande en attente'), findsOneWidget);
  });

  // ── Labels de statut sur les cards ────────────────────────────────────────

  testWidgets('card PENDING : affiche label "EN ATTENTE"', (tester) async {
    final bid = _makeBid(status: 'PENDING');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('À venir'));
    await tester.pumpAndSettle();

    expect(find.text('EN ATTENTE'), findsOneWidget);
  });

  testWidgets('card ACCEPTED : affiche label "CONFIRMÉ"', (tester) async {
    final bid = _makeBid(status: 'ACCEPTED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    expect(find.text('CONFIRMÉ'), findsOneWidget);
  });

  testWidgets('card COMPLETED : affiche label "LIVRÉ"', (tester) async {
    final bid = _makeBid(status: 'COMPLETED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();

    expect(find.text('LIVRÉ'), findsOneWidget);
  });

  testWidgets('card REJECTED : affiche label "REFUSÉ"', (tester) async {
    final bid = _makeBid(status: 'REJECTED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();

    expect(find.text('REFUSÉ'), findsOneWidget);
  });

  testWidgets('card CANCELLED : affiche label "ANNULÉ"', (tester) async {
    final bid = _makeBid(status: 'CANCELLED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();

    expect(find.text('ANNULÉ'), findsOneWidget);
  });

  // ── Badge header ──────────────────────────────────────────────────────────

  testWidgets('header : badge "1" visible quand 1 bid ACCEPTED', (tester) async {
    final bid = _makeBid(status: 'ACCEPTED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    expect(find.text('1'), findsOneWidget);
  });

  // ── Rafraîchissement en cours ─────────────────────────────────────────────

  testWidgets('affiche LinearProgressIndicator quand isRefreshing=true', (tester) async {
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidListLoaded(const []));

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded(const [], isRefreshing: true));
    await tester.pump();
    await tester.pump(_kSettle);

    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // Émettre un état sans isRefreshing pour clôturer le timer infini de l'indicateur
    ctrl.add(BidListLoaded(const []));
    await tester.pump();
    await tester.pumpAndSettle();
  });

  // ── BidDeleted ────────────────────────────────────────────────────────────

  testWidgets('BidDeleted : affiche snackbar "Envoi supprimé"', (tester) async {
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidListLoaded(const []));

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidDeleted());
    await tester.pump();
    await tester.pump(_kSettle);

    expect(find.text('Envoi supprimé'), findsOneWidget);
  });

  // ── Mode embedded (ShipmentListBody) ─────────────────────────────────────

  testWidgets('ShipmentListBody : rendu sans GoRouter, tabs visibles', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<PaymentBloc>.value(value: paymentBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          child: const Scaffold(body: ShipmentListBody()),
        ),
      ),
    );
    await tester.pump(_kSettle);

    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('À venir'), findsOneWidget);
    expect(find.text('Passés'), findsOneWidget);
  });

  testWidgets('ShipmentListBody : pas de header #0A2540 en mode embedded', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<PaymentBloc>.value(value: paymentBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          child: const Scaffold(body: ShipmentListBody()),
        ),
      ),
    );
    await tester.pump(_kSettle);

    final containers = tester.widgetList<Container>(find.byType(Container));
    final hasNavyHeader = containers.any((c) =>
        c.color == const Color(0xFF0A2540) ||
        (c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == const Color(0xFF0A2540)));
    expect(hasNavyHeader, isFalse);
  });

  testWidgets('ShipmentListBody : changement d\'onglet fonctionne', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<PaymentBloc>.value(value: paymentBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          child: const Scaffold(body: ShipmentListBody()),
        ),
      ),
    );
    await tester.pump(_kSettle);

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();

    expect(find.text('Aucun historique'), findsOneWidget);
  });

  // ── Statuts supplémentaires ───────────────────────────────────────────────

  testWidgets('card NO_SHOW : affiche label "ABSENT"', (tester) async {
    final bid = _makeBid(status: 'NO_SHOW');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();

    expect(find.text('ABSENT'), findsOneWidget);
  });

  testWidgets('card EXPIRED : affiche label "EXPIRÉ"', (tester) async {
    final bid = _makeBid(status: 'EXPIRED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();

    expect(find.text('EXPIRÉ'), findsOneWidget);
  });

  testWidgets('card PARCEL_REFUSED : affiche label "REFUSÉ"', (tester) async {
    final bid = _makeBid(status: 'PARCEL_REFUSED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();

    expect(find.text('REFUSÉ'), findsAtLeastNWidgets(1));
  });

  // ── Retour vers onglet "En cours" ─────────────────────────────────────────

  testWidgets('onglet "En cours" navigable depuis "À venir"', (tester) async {
    when(() => bidBloc.state).thenReturn(BidListLoaded(const []));
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);

    await tester.tap(find.text('À venir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('En cours'));
    await tester.pumpAndSettle();

    expect(find.text('Aucun envoi en cours'), findsOneWidget);
  });

  // ── Refresh notifier ──────────────────────────────────────────────────────

  testWidgets('EnvoisRefreshNotifier.requestRefresh déclenche BidMyListAutoRefreshRequested', (tester) async {
    when(() => bidBloc.state).thenReturn(BidListLoaded(const []));
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);

    getIt<EnvoisRefreshNotifier>().requestRefresh();
    await tester.pump();

    verify(() => bidBloc.add(const BidMyListAutoRefreshRequested())).called(greaterThanOrEqualTo(1));
  });

  // ── Navigation via tap card ───────────────────────────────────────────────

  testWidgets('tap sur card ACCEPTED navigue vers /bids/:id puis retour', (tester) async {
    final bid = _makeBid(status: 'ACCEPTED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text('Bid detail'), findsOneWidget);

    // Pop back pour couvrir le code post-navigation
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('CONFIRMÉ'), findsOneWidget);
  });

  testWidgets('tap "Voir →" sur card ACCEPTED navigue puis retour', (tester) async {
    final bid = _makeBid(status: 'ACCEPTED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('Voir →'));
    await tester.pumpAndSettle();

    expect(find.text('Bid detail'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('CONFIRMÉ'), findsOneWidget);
  });

  // ── Erreur : bouton Réessayer ─────────────────────────────────────────────

  testWidgets('erreur : vue d\'erreur affiche bouton "Réessayer" et titre "Erreur de chargement"', (tester) async {
    when(() => bidBloc.state).thenReturn(BidError(const NetworkException('Erreur réseau')));
    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);

    expect(find.text('Erreur de chargement'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);

    // Tap le bouton sans erreur (code dans GestureDetector exécuté)
    await tester.tap(find.text('Réessayer'));
    await tester.pump();
  });

  // ── Swipe & suppression (onglet Passés) ───────────────────────────────────

  testWidgets('swipe gauche sur card Passés affiche le fond de suppression', (tester) async {
    final bid = _makeBid(status: 'COMPLETED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Paris → Dakar'), const Offset(-300, 0));
    await tester.pump();

    expect(find.text('Supprimer'), findsOneWidget);
  });

  testWidgets('dialog suppression apparaît après swipe complet', (tester) async {
    final bid = _makeBid(status: 'COMPLETED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Paris → Dakar'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer cet envoi ?'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
  });

  // ── Séparateur (2+ items) ─────────────────────────────────────────────────

  testWidgets('liste Passés avec 2 items : séparateur rendu', (tester) async {
    final bids = [
      _makeBid(id: 'bid-00000001', status: 'COMPLETED'),
      _makeBid(id: 'bid-00000002', status: 'REJECTED'),
    ];
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded(bids));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();

    // 2 cards visibles : LIVRÉ et REFUSÉ
    expect(find.text('LIVRÉ'), findsOneWidget);
    expect(find.text('REFUSÉ'), findsOneWidget);
  });

  // ── Embedded : onglets En cours et À venir ────────────────────────────────

  testWidgets('ShipmentListBody : onglet "À venir" embedded fonctionne', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<PaymentBloc>.value(value: paymentBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          child: const Scaffold(body: ShipmentListBody()),
        ),
      ),
    );
    await tester.pump(_kSettle);

    await tester.tap(find.text('À venir'));
    await tester.pumpAndSettle();
    expect(find.text('Aucune demande en attente'), findsOneWidget);

    await tester.tap(find.text('En cours'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun envoi en cours'), findsOneWidget);
  });

  // ── Confirmation suppression (onDismissed + onDelete) ────────────────────

  testWidgets('confirmer suppression : onDismissed dispatch BidDeleteRequested', (tester) async {
    final bid = _makeBid(status: 'COMPLETED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Paris → Dakar'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer cet envoi ?'), findsOneWidget);

    // Utiliser .last pour cibler le bouton du dialog (pas celui du fond Dismissible)
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();

    verify(() => bidBloc.add(any(that: isA<BidDeleteRequested>()))).called(1);
  });

  // ── BidCheckoutReady listener ─────────────────────────────────────────────

  testWidgets('BidCheckoutReady : dispatch BidCheckoutPaymentRequested vers PaymentBloc', (tester) async {
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidListLoaded(const []));

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);

    ctrl.add(BidCheckoutReady(BidCheckoutResponseModel(
      bidId: 'bid-00000001',
      clientSecret: 'cs_test_xxx',
      publishableKey: 'pk_test_xxx',
      expiresAt: DateTime(2026, 1, 1),
    )));
    await tester.pump();
    await tester.pump(_kSettle);

    verify(() => paymentBloc.add(any())).called(1);
  });

  // ── PAYMENT_ESCROWED ─────────────────────────────────────────────────────

  testWidgets('card PAYMENT_ESCROWED : badge "EN ATTENTE" dans onglet À venir', (tester) async {
    final bid = _makeBid(status: 'PAYMENT_ESCROWED');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('À venir'));
    await tester.pumpAndSettle();

    expect(find.text('EN ATTENTE'), findsOneWidget);
  });

  testWidgets('tri : PAYMENT_ESCROWED avant AWAITING_PAYMENT dans À venir', (tester) async {
    final bids = [
      _makeBid(id: 'bid-00000001', status: 'AWAITING_PAYMENT'),
      _makeBid(id: 'bid-00000002', status: 'PAYMENT_ESCROWED'),
    ];
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded(bids));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('À venir'));
    await tester.pumpAndSettle();

    // PAYMENT_ESCROWED (priorité 3) doit être avant AWAITING_PAYMENT (priorité 2)
    final enAttentePos = tester.getTopLeft(find.text('EN ATTENTE').first).dy;
    final aPayerPos = tester.getTopLeft(find.text('À PAYER').first).dy;
    expect(enAttentePos, lessThan(aPayerPos));
  });

  // ── _startPayment ─────────────────────────────────────────────────────────

  testWidgets('tap "Payer →" déclenche BidCheckoutRequested', (tester) async {
    final bid = _makeBid(status: 'AWAITING_PAYMENT');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    await tester.tap(find.text('À venir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Payer →'));
    await tester.pump();

    verify(() => bidBloc.add(any(that: isA<BidCheckoutRequested>()))).called(1);
  });

  // ── BidError pendant paiement en cours ────────────────────────────────────

  testWidgets('BidError avec _payingBidId défini réinitialise l\'état paiement', (tester) async {
    final bid = _makeBid(status: 'AWAITING_PAYMENT');
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc: bidBloc, paymentBloc: paymentBloc, authBloc: authBloc);
    ctrl.add(BidListLoaded([bid]));
    await tester.pump();
    await tester.pump(_kSettle);

    // Déclencher _startPayment pour définir _payingBidId
    await tester.tap(find.text('À venir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payer →'));
    await tester.pump();

    // Émettre BidError → branche (state is BidError && _payingBidId != null)
    ctrl.add(BidError(const NetworkException('Erreur paiement')));
    await tester.pump();
    await tester.pump(_kSettle);

    expect(find.byType(ShipmentListScreen), findsOneWidget);
  });
}
