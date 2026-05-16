import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
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

BidModel _makeBid({
  required String status,
  String id = 'bid-00000001',
  String senderName = 'Moussa Traoré',
  String? trackingNumber,
  String? rejectionReason,
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
      trackingNumber: trackingNumber,
      rejectionReason: rejectionReason,
      status: status,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: updatedAt ?? DateTime(2026, 5, 1),
    );

Future<void> _pump(
  WidgetTester tester,
  MockBidBloc bidBloc, {
  MockBidAcceptanceBloc? acceptanceBloc,
  int initialTabIndex = 0,
}) async {
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
            BlocProvider<BidAcceptanceBloc>.value(
                value: acceptanceBloc ?? MockBidAcceptanceBloc()),
          ],
          child: BidListScreenTesting(
            announcementId: 'ann-1',
            initialTabIndex: initialTabIndex,
          ),
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
        path: '/tracking/scan',
        builder: (_, __) => const Scaffold(body: Text('scan')),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
  await tester.pump();
}

/// Branche un stream de states sur le bloc mocké et renvoie le controller.
StreamController<BidState> _wireStates(
    MockBidBloc bidBloc, WidgetTester tester) {
  final ctrl = StreamController<BidState>.broadcast();
  whenListen(bidBloc, ctrl.stream, initialState: BidInitial());
  return ctrl;
}

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

  // ── Onglet « En attente » ───────────────────────────────────────────────────

  testWidgets('PAYMENT_ESCROWED apparaît dans « En attente » avec badge et boutons',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PAYMENT_ESCROWED')]));
    await tester.pumpAndSettle();

    expect(find.textContaining('Paiement reçu'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
  });

  testWidgets('PENDING apparaît dans « En attente » sans badge Paiement reçu',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING')]));
    await tester.pumpAndSettle();

    expect(find.text('Refuser'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
    expect(find.textContaining('Paiement reçu'), findsNothing);
  });

  testWidgets(
      'PENDING + PAYMENT_ESCROWED comptent dans le compteur « En attente »',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'PENDING', id: 'bid-1'),
      _makeBid(status: 'PAYMENT_ESCROWED', id: 'bid-2'),
      _makeBid(status: 'ACCEPTED', id: 'bid-3'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Accepter'), findsNWidgets(2));
  });

  // ── Onglet « Acceptées » — statuts ──────────────────────────────────────────

  testWidgets('les 7 statuts post-acceptation s\'affichent avec le bon libellé',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1'),
      _makeBid(status: 'HANDED_OVER', id: 'b2'),
      _makeBid(status: 'IN_TRANSIT', id: 'b3'),
      _makeBid(status: 'COMPLETED', id: 'b4'),
      _makeBid(status: 'NO_SHOW', id: 'b5'),
      _makeBid(status: 'PARCEL_REFUSED', id: 'b6'),
      _makeBid(status: 'CANCELLED', id: 'b7'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Acceptées (7)'), findsOneWidget);
    expect(find.text('Accepté'), findsOneWidget);
    expect(find.text('En route'), findsOneWidget);
    expect(find.text('En transit'), findsOneWidget);
    expect(find.text('Livré'), findsOneWidget);
    expect(find.text('Absent'), findsOneWidget);
    expect(find.text('Colis refusé'), findsOneWidget);
    expect(find.text('Annulé'), findsOneWidget);
  });

  testWidgets('CANCELLED auto (TRAVELER_NO_RESPONSE) est exclu de la liste',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1'),
      _makeBid(
          status: 'CANCELLED',
          id: 'b2',
          rejectionReason: 'TRAVELER_NO_RESPONSE'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Acceptées (1)'), findsOneWidget);
    expect(find.text('Annulé'), findsNothing);
    expect(find.byType(DonyAvatar), findsOneWidget);
  });

  // ── Recherche ───────────────────────────────────────────────────────────────

  testWidgets('la recherche par nom filtre la liste', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1', senderName: 'Moussa Traoré'),
      _makeBid(status: 'IN_TRANSIT', id: 'b2', senderName: 'Awa Diop'),
    ]));
    await tester.pumpAndSettle();

    expect(find.byType(DonyAvatar), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'awa');
    await tester.pumpAndSettle();

    expect(find.byType(DonyAvatar), findsOneWidget);
    expect(find.text('En transit'), findsOneWidget);
    expect(find.text('Accepté'), findsNothing);
  });

  testWidgets('la recherche par numéro de suivi filtre la liste',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(
          status: 'ACCEPTED',
          id: 'b1',
          senderName: 'Moussa Traoré',
          trackingNumber: 'DNY-4815'),
      _makeBid(
          status: 'IN_TRANSIT',
          id: 'b2',
          senderName: 'Awa Diop',
          trackingNumber: 'DNY-9999'),
    ]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'DNY-48');
    await tester.pumpAndSettle();

    expect(find.byType(DonyAvatar), findsOneWidget);
    expect(find.text('Accepté'), findsOneWidget);
    expect(find.text('En transit'), findsNothing);
  });

  testWidgets('recherche infructueuse → état vide « Aucun résultat »',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1', senderName: 'Moussa Traoré'),
    ]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.byType(DonyAvatar), findsNothing);
    expect(find.text('Aucun résultat'), findsOneWidget);
    expect(find.textContaining('« zzz »'), findsOneWidget);
  });

  // ── Filtre statut ───────────────────────────────────────────────────────────

  testWidgets('le filtre « Clôturés » n\'affiche que les bids clôturés',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1'),
      _makeBid(status: 'IN_TRANSIT', id: 'b2'),
      _makeBid(status: 'NO_SHOW', id: 'b3'),
      _makeBid(status: 'CANCELLED', id: 'b4'),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clôturés (2)'));
    await tester.pumpAndSettle();

    expect(find.byType(DonyAvatar), findsNWidgets(2));
    expect(find.text('Absent'), findsOneWidget);
    expect(find.text('Annulé'), findsOneWidget);
    expect(find.text('Accepté'), findsNothing);
    expect(find.text('En transit'), findsNothing);
  });

  testWidgets('le filtre « Actifs » n\'affiche que les bids actifs',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1'),
      _makeBid(status: 'NO_SHOW', id: 'b2'),
      _makeBid(status: 'CANCELLED', id: 'b3'),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Actifs (1)'));
    await tester.pumpAndSettle();

    expect(find.byType(DonyAvatar), findsOneWidget);
    expect(find.text('Accepté'), findsOneWidget);
    expect(find.text('Absent'), findsNothing);
  });

  testWidgets('recherche et filtre se cumulent', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1', senderName: 'Moussa Traoré'),
      _makeBid(status: 'CANCELLED', id: 'b2', senderName: 'Moussa Diop'),
      _makeBid(status: 'CANCELLED', id: 'b3', senderName: 'Awa Sow'),
    ]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'moussa');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clôturés (1)'));
    await tester.pumpAndSettle();

    expect(find.byType(DonyAvatar), findsOneWidget);
    expect(find.text('Annulé'), findsOneWidget);
  });

  testWidgets('les compteurs des chips sont recalculés sur la recherche',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1', senderName: 'Moussa Traoré'),
      _makeBid(status: 'ACCEPTED', id: 'b2', senderName: 'Moussa Diop'),
      _makeBid(status: 'NO_SHOW', id: 'b3', senderName: 'Awa Sow'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Tous (3)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'moussa');
    await tester.pumpAndSettle();

    expect(find.text('Tous (2)'), findsOneWidget);
    expect(find.text('Actifs (2)'), findsOneWidget);
    expect(find.text('Clôturés (0)'), findsOneWidget);
  });

  // ── Onglet ouvert par défaut ────────────────────────────────────────────────

  testWidgets('auto-sélection de « Acceptées » quand « En attente » est vide',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'ACCEPTED')]));
    await tester.pumpAndSettle();

    expect(find.byType(DonySearchField), findsOneWidget);
  });

  testWidgets('pas d\'auto-sélection quand « En attente » n\'est pas vide',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'PENDING', id: 'b1'),
      _makeBid(status: 'ACCEPTED', id: 'b2'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Accepter'), findsOneWidget);
    expect(find.byType(DonySearchField), findsNothing);
  });
}
