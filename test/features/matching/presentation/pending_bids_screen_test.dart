import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/pending_bids_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class MockBidAcceptanceBloc
    extends MockBloc<ace.BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

// ── Helpers ───────────────────────────────────────────────────────────────────

BidModel _makeBid({
  required String status,
  String id = 'bid-00000001',
  String senderName = 'Moussa Traoré',
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
  DateTime? updatedAt,
}) =>
    BidModel(
      id: id,
      announcementId: 'ann-1',
      senderId: 'sender-1',
      senderName: senderName,
      weightKg: 3,
      pricePerKg: 15,
      contentCategory: 'Vêtements',
      status: status,
      paymentMethod: paymentMethod,
      createdAt: DateTime(2026, 5),
      updatedAt: updatedAt ?? DateTime(2026, 5),
    );

Future<void> _pump(
  WidgetTester tester,
  MockBidBloc bidBloc,
  MockBidAcceptanceBloc acceptanceBloc,
) async {
  await initializeDateFormatting('fr_FR');
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => MultiBlocProvider(
          providers: [
            BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<BidAcceptanceBloc>.value(value: acceptanceBloc),
          ],
          child: const PendingBidsScreenTesting(announcementId: 'ann-1'),
        ),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (_, state) => Scaffold(
          appBar: AppBar(),
          body: Text('Bid detail ${state.pathParameters['id']}'),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
  await tester.pump();
}

/// Pump from a non-poppable root so context.canPop() == false.
Future<void> _pumpFromRoot(
  WidgetTester tester,
  MockBidBloc bidBloc,
  MockBidAcceptanceBloc acceptanceBloc,
) async {
  await initializeDateFormatting('fr_FR');
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final router = GoRouter(
    initialLocation: '/screen',
    routes: [
      GoRoute(
        path: '/screen',
        builder: (ctx, _) => MultiBlocProvider(
          providers: [
            BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<BidAcceptanceBloc>.value(value: acceptanceBloc),
          ],
          child: const PendingBidsScreenTesting(announcementId: 'ann-1'),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
  await tester.pump();
}

StreamController<BidState> _wireStates(MockBidBloc bidBloc) {
  final ctrl = StreamController<BidState>.broadcast();
  whenListen(bidBloc, ctrl.stream, initialState: BidInitial());
  return ctrl;
}

void main() {
  setUpAll(() {
    registerFallbackValue(BidListRequested('ann-1'));
    registerFallbackValue(BidAcceptRequested('fallback'));
    registerFallbackValue(BidRejectRequested('fallback'));
    registerFallbackValue(ace.BidAcceptRequested('fallback'));
  });

  late MockBidBloc bidBloc;
  late MockBidAcceptanceBloc acceptanceBloc;
  late _MockAnalyticsService analytics;

  setUp(() {
    bidBloc = MockBidBloc();
    acceptanceBloc = MockBidAcceptanceBloc();
    analytics = _MockAnalyticsService();

    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => acceptanceBloc.state).thenReturn(acs.BidAcceptanceInitial());
    when(() => analytics.logEvent(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    bidBloc.close();
    acceptanceBloc.close();
  });

  // ── Titre ───────────────────────────────────────────────────────────────────

  testWidgets('titre affiche « À traiter (2) » avec 2 demandes en attente',
      (tester) async {
    final ctrl = _wireStates(bidBloc);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'PAYMENT_ESCROWED', id: 'p1'),
      _makeBid(status: 'PENDING', id: 'p2'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('À traiter (2)'), findsOneWidget);
  });

  // ── Cartes en attente ───────────────────────────────────────────────────────

  testWidgets(
      'carte PAYMENT_ESCROWED → bandeau « Paiement reçu » + Refuser + Accepter',
      (tester) async {
    final ctrl = _wireStates(bidBloc);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PAYMENT_ESCROWED')]));
    await tester.pumpAndSettle();

    expect(find.textContaining('Paiement reçu'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
  });

  testWidgets(
      'carte PENDING (cash) → bandeau « Paiement en espèces »',
      (tester) async {
    final ctrl = _wireStates(bidBloc);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'PENDING', paymentMethod: BidPaymentMethod.cash),
    ]));
    await tester.pumpAndSettle();

    expect(find.textContaining('Paiement en espèces'), findsOneWidget);
    expect(find.textContaining('Paiement reçu'), findsNothing);
  });

  // ── Accepter — dispatch selon mode de paiement ──────────────────────────────

  testWidgets(
      'tap Accepter sur bid CASH → BidAcceptanceBloc.add(BidAcceptRequested)',
      (tester) async {
    final ctrl = _wireStates(bidBloc);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(
        status: 'PAYMENT_ESCROWED',
        id: 'cash-1',
        paymentMethod: BidPaymentMethod.cash,
      ),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accepter'));
    await tester.pump();

    verify(() => acceptanceBloc.add(any(that: isA<ace.BidAcceptRequested>())))
        .called(1);
    verifyNever(() => bidBloc.add(any(that: isA<BidAcceptRequested>())));
  });

  testWidgets(
      'tap Accepter sur bid STRIPE → BidBloc.add(BidAcceptRequested)',
      (tester) async {
    final ctrl = _wireStates(bidBloc);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(
        status: 'PAYMENT_ESCROWED',
        id: 'stripe-1',
      ),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accepter'));
    await tester.pump();

    verify(() => bidBloc.add(any(that: isA<BidAcceptRequested>()))).called(1);
    verifyNever(
        () => acceptanceBloc.add(any(that: isA<ace.BidAcceptRequested>())));
  });

  // ── Refuser → dialog → confirmer ────────────────────────────────────────────

  testWidgets(
      'tap Refuser → confirme le dialog → BidBloc.add(BidRejectRequested)',
      (tester) async {
    final ctrl = _wireStates(bidBloc);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING', id: 'bid-r1')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refuser'));
    await tester.pumpAndSettle();

    // Dialog de confirmation ouvert.
    expect(find.textContaining('Refuser cette demande'), findsOneWidget);

    // Bouton de confirmation = dernier « Refuser » (celui du dialog).
    await tester.tap(find.text('Refuser').last);
    await tester.pumpAndSettle();

    verify(() => bidBloc.add(any(that: isA<BidRejectRequested>()))).called(1);
  });

  // ── Rafraîchissement après action ───────────────────────────────────────────

  testWidgets(
      'après BidRejected puis BidAccepted, recharge la liste (BidListRequested)',
      (tester) async {
    final ctrl = _wireStates(bidBloc);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PAYMENT_ESCROWED', id: 'b1')]));
    await tester.pumpAndSettle();

    // Refus réussi (réponse serveur) → la liste doit se recharger.
    ctrl.add(BidRejected(_makeBid(status: 'REJECTED', id: 'b1')));
    await tester.pumpAndSettle();
    verify(() => bidBloc.add(any(that: isA<BidListRequested>()))).called(1);

    // Acceptation réussie → idem.
    ctrl.add(BidAccepted(_makeBid(status: 'ACCEPTED', id: 'b1')));
    await tester.pumpAndSettle();
    verify(() => bidBloc.add(any(that: isA<BidListRequested>()))).called(1);
  });

  testWidgets(
      'tap carte → détail → retour recharge la liste (refresh après navigation)',
      (tester) async {
    final ctrl = _wireStates(bidBloc);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PAYMENT_ESCROWED', id: 'b1')]));
    await tester.pumpAndSettle();

    // Tap le corps de la carte (nom expéditeur) → ouvre le détail.
    await tester.tap(find.text('Moussa Traoré'));
    await tester.pumpAndSettle();
    expect(find.text('Bid detail b1'), findsOneWidget);

    // Retour depuis le détail → la liste doit se recharger seule.
    await tester.pageBack();
    await tester.pumpAndSettle();
    verify(() => bidBloc.add(any(that: isA<BidListRequested>()))).called(1);
  });

  // ── Empty state ─────────────────────────────────────────────────────────────

  testWidgets('liste vide → « Aucune demande à traiter »', (tester) async {
    // État chargé fourni dès le 1er frame (comme initialState) : l'empty state
    // (mascotte animée) se rend une fois et un seul pump(durée) draine
    // l'animation flutter_animate sans laisser de timer en vol après dispose.
    final loaded = BidListLoaded([_makeBid(status: 'ACCEPTED')]);
    when(() => bidBloc.state).thenReturn(loaded);
    whenListen(bidBloc, const Stream<BidState>.empty(), initialState: loaded);

    await _pump(tester, bidBloc, acceptanceBloc);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Aucune demande à traiter'), findsOneWidget);
    expect(find.text('À traiter'), findsOneWidget);
  });

  // ── Bouton retour ───────────────────────────────────────────────────────────

  testWidgets('bouton retour → navigue /home quand non poppable',
      (tester) async {
    final ctrl = _wireStates(bidBloc);
    addTearDown(ctrl.close);

    await _pumpFromRoot(tester, bidBloc, acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });
}
