import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/bid_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class MockBidAcceptanceBloc
    extends MockBloc<BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

// ── Helpers ───────────────────────────────────────────────────────────────────

BidModel _makeBid({required String status, String id = 'bid-00000001'}) =>
    BidModel(
      id: id,
      announcementId: 'ann-1',
      senderId: 'sender-1',
      senderName: 'Moussa Traoré',
      weightKg: 3,
      status: status,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );


Future<void> _pump(WidgetTester tester, MockBidBloc bidBloc,
    {MockBidAcceptanceBloc? acceptanceBloc}) async {
  await initializeDateFormatting('fr_FR');
  tester.view.physicalSize = const Size(800, 1400);
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
            BlocProvider<BidAcceptanceBloc>.value(
                value: acceptanceBloc ?? MockBidAcceptanceBloc()),
          ],
          child: const BidListScreenTesting(announcementId: 'ann-1'),
        ),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (_, state) => Scaffold(
          appBar: AppBar(),
          body: Text('Bid detail ${state.pathParameters['id']}'),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
    ),
  );
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(BidListRequested('ann-1'));
  });

  late MockBidBloc bidBloc;
  late MockBidAcceptanceBloc acceptanceBloc;

  setUp(() {
    bidBloc = MockBidBloc();
    acceptanceBloc = MockBidAcceptanceBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => acceptanceBloc.state).thenReturn(acs.BidAcceptanceInitial());
  });

  tearDown(() {
    bidBloc.close();
    acceptanceBloc.close();
  });

  // ── Filtrage onglet "En attente" ───────────────────────────────────────────

  testWidgets('PAYMENT_ESCROWED apparaît dans "En attente" avec badge et boutons',
      (tester) async {
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PAYMENT_ESCROWED')]));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Paiement reçu'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
  });

  testWidgets('PENDING apparaît dans "En attente" sans badge Paiement reçu',
      (tester) async {
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING')]));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Refuser'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
    expect(find.textContaining('Paiement reçu'), findsNothing);
  });

  testWidgets('ACCEPTED N\'apparaît pas dans onglet "En attente"',
      (tester) async {
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'ACCEPTED')]));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Moussa Traoré'), findsNothing);
    expect(find.textContaining('Aucune demande en attente'), findsOneWidget);
  });

  testWidgets(
      'PENDING + PAYMENT_ESCROWED comptent tous les deux dans le compteur "En attente"',
      (tester) async {
    final bids = [
      _makeBid(status: 'PENDING', id: 'bid-1'),
      _makeBid(status: 'PAYMENT_ESCROWED', id: 'bid-2'),
      _makeBid(status: 'ACCEPTED', id: 'bid-3'),
    ];
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded(bids));
    await tester.pump();
    await tester.pumpAndSettle();

    // 2 bids en attente (PENDING + PAYMENT_ESCROWED)
    expect(find.textContaining('2'), findsWidgets);
    // Les deux cartes visibles
    expect(find.text('Moussa Traoré'), findsNWidgets(2));
  });

  // ── Filtrage onglet "Acceptées" ────────────────────────────────────────────

  testWidgets('HANDED_OVER apparaît dans l\'onglet "Acceptées" avec badge En route',
      (tester) async {
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'HANDED_OVER')]));
    await tester.pump();
    await tester.pumpAndSettle();

    // Le compteur de l'onglet Acceptées vaut 1
    expect(find.text('Acceptées (1)'), findsOneWidget);

    // Basculer sur l'onglet "Acceptées"
    await tester.tap(find.text('Acceptées (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Moussa Traoré'), findsOneWidget);
    expect(find.textContaining('En route'), findsOneWidget);
  });

  testWidgets(
      'ACCEPTED + HANDED_OVER + IN_TRANSIT + COMPLETED comptent dans "Acceptées"',
      (tester) async {
    final bids = [
      _makeBid(status: 'ACCEPTED', id: 'bid-1'),
      _makeBid(status: 'HANDED_OVER', id: 'bid-2'),
      _makeBid(status: 'IN_TRANSIT', id: 'bid-3'),
      _makeBid(status: 'COMPLETED', id: 'bid-4'),
    ];
    final ctrl = StreamController<BidState>.broadcast();
    addTearDown(ctrl.close);
    whenListen(bidBloc, ctrl.stream, initialState: BidInitial());

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded(bids));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Acceptées (4)'), findsOneWidget);
  });
}
