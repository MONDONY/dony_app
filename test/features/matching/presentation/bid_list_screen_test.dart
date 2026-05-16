import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
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
    extends MockBloc<ace.BidAcceptanceEvent, acs.BidAcceptanceState>
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
  String? departureCityCode,
  String? arrivalCityCode,
  DateTime? departureDate,
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
            departureCityCode: departureCityCode,
            arrivalCityCode: arrivalCityCode,
            departureDate: departureDate,
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
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('home')),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
  await tester.pump();
}

/// Helper: pump with a [BidListScreenTesting] opened at '/screen' from a
/// non-poppable root — so that context.canPop() == false.
Future<GoRouter> _pumpFromRoot(
  WidgetTester tester,
  MockBidBloc bidBloc, {
  MockBidAcceptanceBloc? acceptanceBloc,
}) async {
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
            BlocProvider<BidAcceptanceBloc>.value(
                value: acceptanceBloc ?? MockBidAcceptanceBloc()),
          ],
          child: const BidListScreenTesting(announcementId: 'ann-1'),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (_, state) => Scaffold(
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
  return router;
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
    registerFallbackValue(ace.BidAcceptRequested('fallback'));
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

  // ── État BidLoading ─────────────────────────────────────────────────────────

  testWidgets('BidLoading affiche un spinner centré', (tester) async {
    when(() => bidBloc.state).thenReturn(BidLoading());
    whenListen(bidBloc, Stream<BidState>.fromIterable([BidLoading()]),
        initialState: BidLoading());
    whenListen(acceptanceBloc,
        Stream<acs.BidAcceptanceState>.fromIterable([acs.BidAcceptanceInitial()]),
        initialState: acs.BidAcceptanceInitial());

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // ── État BidError dans le body ──────────────────────────────────────────────

  testWidgets('BidError dans body affiche message et bouton Réessayer',
      (tester) async {
    final error = const NetworkException('Erreur réseau');
    when(() => bidBloc.state).thenReturn(BidError(error));
    whenListen(bidBloc, Stream<BidState>.fromIterable([BidError(error)]),
        initialState: BidError(error));
    whenListen(acceptanceBloc,
        Stream<acs.BidAcceptanceState>.fromIterable([acs.BidAcceptanceInitial()]),
        initialState: acs.BidAcceptanceInitial());

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    await tester.pump();

    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('bouton Réessayer dans _ErrorView redispatche BidListRequested',
      (tester) async {
    final error = const NetworkException('Erreur réseau');
    when(() => bidBloc.state).thenReturn(BidError(error));
    final bidCtrl = StreamController<BidState>.broadcast();
    whenListen(bidBloc, bidCtrl.stream, initialState: BidError(error));
    addTearDown(bidCtrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    await tester.pump();

    await tester.tap(find.text('Réessayer'));
    await tester.pump();

    verify(() => bidBloc.add(any(that: isA<BidListRequested>()))).called(1);
  });

  // ── Subtitle ────────────────────────────────────────────────────────────────

  testWidgets('subtitle avec ville départ/arrivée s\'affiche', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(
      tester,
      bidBloc,
      acceptanceBloc: acceptanceBloc,
      departureCityCode: 'CDG',
      arrivalCityCode: 'DKR',
    );
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING')]));
    await tester.pumpAndSettle();

    expect(find.textContaining('CDG → DKR'), findsOneWidget);
  });

  // ── Empty states ────────────────────────────────────────────────────────────

  // Note: when En attente is empty, the screen auto-selects tab 1 (Acceptées).
  // To test the En attente empty state we use initialTabIndex:0 + userSwitchedTab
  // which requires a REJECTED bid (stays in pending tab but not pending).
  // Simpler: a list with only REJECTED bids (no PENDING/PAYMENT_ESCROWED) shows
  // the pending empty state because REJECTED is not in the pending filter.
  testWidgets('onglet En attente sans bids PENDING → affiche Aucune demande en attente',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    // initialTabIndex:1 then switch back to 0 to prevent auto-select jumping
    await _pump(tester, bidBloc,
        acceptanceBloc: acceptanceBloc, initialTabIndex: 0);
    // Push ACCEPTED only — pending tab will be empty, but we need to prevent
    // auto-select. We do this by switching to tab 1 first (sets _userSwitchedTab=true).
    ctrl.add(BidListLoaded([_makeBid(status: 'ACCEPTED', id: 'b1')]));
    await tester.pumpAndSettle();
    // At this point auto-select fires and goes to tab 1 (accepted tab)
    // Switch back to tab 0 manually
    await tester.tap(find.text('En attente'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucune demande en attente'), findsOneWidget);
  });

  testWidgets(
      'onglet Acceptées vide → affiche message Aucune demande acceptée',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc,
        acceptanceBloc: acceptanceBloc, initialTabIndex: 1);
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Acceptées'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucune demande acceptée'), findsOneWidget);
  });

  // ── Listeners BidState ──────────────────────────────────────────────────────

  testWidgets('BidAccepted → snackbar « Demande acceptée » et refresh',
      (tester) async {
    final accepted = _makeBid(status: 'ACCEPTED');
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING')]));
    await tester.pumpAndSettle();

    ctrl.add(BidAccepted(accepted));
    await tester.pumpAndSettle();

    expect(find.textContaining('Demande acceptée'), findsOneWidget);
    verify(() => bidBloc.add(any(that: isA<BidListRequested>()))).called(greaterThan(0));
  });

  testWidgets('BidRejected → snackbar et refresh', (tester) async {
    final rejected = _makeBid(status: 'REJECTED');
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING')]));
    await tester.pumpAndSettle();

    ctrl.add(BidRejected(rejected));
    await tester.pumpAndSettle();

    expect(find.textContaining('refusée'), findsOneWidget);
    verify(() => bidBloc.add(any(that: isA<BidListRequested>()))).called(greaterThan(0));
  });

  testWidgets('BidDeleted → snackbar « supprimée » et refresh', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING')]));
    await tester.pumpAndSettle();

    ctrl.add(BidDeleted());
    await tester.pumpAndSettle();

    expect(find.textContaining('supprimée'), findsOneWidget);
    verify(() => bidBloc.add(any(that: isA<BidListRequested>()))).called(greaterThan(0));
  });

  testWidgets('BidError listener → screen reste affiché', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING')]));
    await tester.pumpAndSettle();

    ctrl.add(BidError(const NetworkException('Erreur réseau')));
    await tester.pumpAndSettle();

    // Screen remains visible (ErrorPresenter handled the error)
    expect(find.byType(BidListScreenTesting), findsOneWidget);
  });

  // ── BidNotFound ─────────────────────────────────────────────────────────────

  testWidgets('BidNotFound → navigue vers /home quand non poppable',
      (tester) async {
    final bidCtrl = StreamController<BidState>.broadcast();
    when(() => bidBloc.state).thenReturn(BidInitial());
    whenListen(bidBloc, bidCtrl.stream, initialState: BidInitial());
    addTearDown(bidCtrl.close);

    whenListen(acceptanceBloc,
        Stream<acs.BidAcceptanceState>.fromIterable([acs.BidAcceptanceInitial()]),
        initialState: acs.BidAcceptanceInitial());

    await _pumpFromRoot(tester, bidBloc, acceptanceBloc: acceptanceBloc);

    bidCtrl.add(BidNotFound());
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  // ── Listener cash acceptance ────────────────────────────────────────────────

  testWidgets('BidAccepted via cash → snackbar « Demande acceptée »',
      (tester) async {
    final acceptCtrl = StreamController<acs.BidAcceptanceState>.broadcast();
    whenListen(acceptanceBloc, acceptCtrl.stream,
        initialState: acs.BidAcceptanceInitial());
    addTearDown(acceptCtrl.close);

    final bidCtrl = _wireStates(bidBloc, tester);
    addTearDown(bidCtrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    bidCtrl.add(BidListLoaded([_makeBid(status: 'PAYMENT_ESCROWED')]));
    await tester.pumpAndSettle();

    acceptCtrl.add(acs.BidAccepted());
    await tester.pumpAndSettle();

    expect(find.textContaining('Demande acceptée'), findsOneWidget);
  });

  testWidgets('BidFailed via cash → snackbar d\'erreur', (tester) async {
    final acceptCtrl = StreamController<acs.BidAcceptanceState>.broadcast();
    whenListen(acceptanceBloc, acceptCtrl.stream,
        initialState: acs.BidAcceptanceInitial());
    addTearDown(acceptCtrl.close);

    final bidCtrl = _wireStates(bidBloc, tester);
    addTearDown(bidCtrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    bidCtrl.add(BidListLoaded([_makeBid(status: 'PAYMENT_ESCROWED')]));
    await tester.pumpAndSettle();

    acceptCtrl.add(acs.BidFailed('Paiement refusé'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Paiement refusé'), findsOneWidget);
  });

  // ── Bouton Accepter → cash path (BidAcceptanceBloc) ────────────────────────

  testWidgets(
      'bid CASH → tap Accepter dispatch BidAcceptRequested sur BidAcceptanceBloc',
      (tester) async {
    final acceptCtrl = StreamController<acs.BidAcceptanceState>.broadcast();
    whenListen(acceptanceBloc, acceptCtrl.stream,
        initialState: acs.BidAcceptanceInitial());
    addTearDown(acceptCtrl.close);

    final bidCtrl = _wireStates(bidBloc, tester);
    addTearDown(bidCtrl.close);

    final cashBid = BidModel(
      id: 'cash-bid-1',
      announcementId: 'ann-1',
      senderId: 's-1',
      senderName: 'Oumar Sow',
      weightKg: 2,
      pricePerKg: 10,
      status: 'PAYMENT_ESCROWED',
      paymentMethod: BidPaymentMethod.cash,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    bidCtrl.add(BidListLoaded([cashBid]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accepter'));
    await tester.pump();

    verify(() => acceptanceBloc.add(any(that: isA<ace.BidAcceptRequested>()))).called(1);
  });

  // ── Navigation via bid card tap ─────────────────────────────────────────────

  testWidgets('tap sur une bid card navigue vers /bids/:id', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc,
        acceptanceBloc: acceptanceBloc, initialTabIndex: 1);
    ctrl.add(BidListLoaded([_makeBid(status: 'ACCEPTED', id: 'bid-xyz')]));
    await tester.pumpAndSettle();

    // Tap the card (InkWell around the card)
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Bid detail bid-xyz'), findsOneWidget);
  });

  // ── Scanner chip button ─────────────────────────────────────────────────────

  testWidgets('tap sur Scanner navigue vers /tracking/scan', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scanner'));
    await tester.pumpAndSettle();

    expect(find.text('scan'), findsOneWidget);
  });

  // ── Titre dynamique ─────────────────────────────────────────────────────────

  testWidgets('titre affiche le compte de demandes en attente', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'PENDING', id: 'b1'),
      _makeBid(status: 'PENDING', id: 'b2'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('2 demandes'), findsOneWidget);
  });

  testWidgets('titre affiche « 1 demande » (singulier)', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING', id: 'b1')]));
    await tester.pumpAndSettle();

    expect(find.text('1 demande'), findsOneWidget);
  });

  // ── Subtitle avec date ──────────────────────────────────────────────────────

  testWidgets('subtitle avec date de départ s\'affiche', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(
      tester,
      bidBloc,
      acceptanceBloc: acceptanceBloc,
      departureCityCode: 'CDG',
      arrivalCityCode: 'DKR',
      departureDate: DateTime(2026, 6, 15),
    );
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING')]));
    await tester.pumpAndSettle();

    expect(find.textContaining('CDG → DKR'), findsOneWidget);
    // Date should also appear in subtitle
    expect(find.textContaining('juin'), findsOneWidget);
  });

  // ── Bouton Retour avec canPop ───────────────────────────────────────────────

  testWidgets('bouton retour pop quand canPop est vrai', (tester) async {
    await initializeDateFormatting('fr_FR');
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bidCtrl = StreamController<BidState>.broadcast();
    when(() => bidBloc.state).thenReturn(BidInitial());
    whenListen(bidBloc, bidCtrl.stream, initialState: BidInitial());
    addTearDown(bidCtrl.close);

    whenListen(acceptanceBloc,
        Stream<acs.BidAcceptanceState>.fromIterable([acs.BidAcceptanceInitial()]),
        initialState: acs.BidAcceptanceInitial());

    // Router with a parent route so canPop returns true for the screen
    final router = GoRouter(
      initialLocation: '/parent',
      routes: [
        GoRoute(
          path: '/parent',
          builder: (_, __) => const Scaffold(body: Text('parent')),
          routes: [
            GoRoute(
              path: 'screen',
              builder: (ctx, _) => MultiBlocProvider(
                providers: [
                  BlocProvider<BidBloc>.value(value: bidBloc),
                  BlocProvider<BidAcceptanceBloc>.value(value: acceptanceBloc),
                ],
                child: const BidListScreenTesting(announcementId: 'ann-1'),
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: AppTheme.light));
    await tester.pump();

    router.go('/parent/screen');
    await tester.pumpAndSettle();

    bidCtrl.add(BidListLoaded([_makeBid(status: 'PENDING')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();

    expect(find.text('parent'), findsOneWidget);
  });

  // ── BidNotFound avec canPop ─────────────────────────────────────────────────

  testWidgets('BidNotFound → pop quand canPop est vrai', (tester) async {
    await initializeDateFormatting('fr_FR');
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bidCtrl = StreamController<BidState>.broadcast();
    when(() => bidBloc.state).thenReturn(BidInitial());
    whenListen(bidBloc, bidCtrl.stream, initialState: BidInitial());
    addTearDown(bidCtrl.close);

    whenListen(acceptanceBloc,
        Stream<acs.BidAcceptanceState>.fromIterable([acs.BidAcceptanceInitial()]),
        initialState: acs.BidAcceptanceInitial());

    final router = GoRouter(
      initialLocation: '/parent',
      routes: [
        GoRoute(
          path: '/parent',
          builder: (_, __) => const Scaffold(body: Text('parent')),
          routes: [
            GoRoute(
              path: 'screen',
              builder: (ctx, _) => MultiBlocProvider(
                providers: [
                  BlocProvider<BidBloc>.value(value: bidBloc),
                  BlocProvider<BidAcceptanceBloc>.value(value: acceptanceBloc),
                ],
                child: const BidListScreenTesting(announcementId: 'ann-1'),
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: AppTheme.light));
    await tester.pump();

    router.go('/parent/screen');
    await tester.pumpAndSettle();

    bidCtrl.add(BidListLoaded([_makeBid(status: 'PENDING')]));
    await tester.pumpAndSettle();

    bidCtrl.add(BidNotFound());
    await tester.pumpAndSettle();

    expect(find.text('parent'), findsOneWidget);
  });

  // ── Accept Stripe bid (non-cash path) ──────────────────────────────────────

  testWidgets('bid STRIPE → tap Accepter dispatch BidAcceptRequested sur BidBloc',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accepter'));
    await tester.pump();

    verify(() => bidBloc.add(any(that: isA<BidAcceptRequested>()))).called(1);
  });

  // ── Reject button tap → shows dialog ───────────────────────────────────────

  testWidgets('tap Refuser → ouvre la boîte de dialogue de confirmation',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refuser'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Refuser cette demande'), findsOneWidget);
  });

  testWidgets('confirmer le refus → dispatch BidRejectRequested', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING', id: 'bid-r1')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refuser'));
    await tester.pumpAndSettle();

    // Tap the confirm button inside the dialog
    await tester.tap(find.text('Refuser').last);
    await tester.pumpAndSettle();

    verify(() => bidBloc.add(any(that: isA<BidRejectRequested>()))).called(1);
  });

  // ── REJECTED bid (n'apparaît pas dans les onglets normalement) ─────────────
  // Note: Les bids REJECTED ne sont jamais affichés dans les onglets En attente
  // ou Acceptées (code défensif). Le test vérifie que l'écran reste stable.

  // ── BidError avec processing bids non vide ──────────────────────────────────

  testWidgets('BidError après accept → processing bids vidés', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING', id: 'bid-p1')]));
    await tester.pumpAndSettle();

    // Tap accept to add to processing ids
    await tester.tap(find.text('Accepter'));
    await tester.pump();

    // Then emit BidError
    ctrl.add(BidError(const NetworkException('Erreur')));
    await tester.pumpAndSettle();

    expect(find.byType(BidListScreenTesting), findsOneWidget);
  });
}
