import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
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
      createdAt: DateTime(2026, 5),
      updatedAt: updatedAt ?? DateTime(2026, 5),
    );

Future<void> _pump(
  WidgetTester tester,
  MockBidBloc bidBloc, {
  String? departureCityCode,
  String? arrivalCityCode,
  DateTime? departureDate,
  String title = 'Demandes',
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
        builder: (ctx, _) => BlocProvider<BidBloc>.value(
          value: bidBloc,
          child: BidListScreenTesting(
            announcementId: 'ann-1',
            departureCityCode: departureCityCode,
            arrivalCityCode: arrivalCityCode,
            departureDate: departureDate,
            title: title,
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
        builder: (_, _) => const Scaffold(body: Text('scan')),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/announcements/:id/bids/pending',
        builder: (_, _) => const Scaffold(body: Text('pending screen')),
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
  MockBidBloc bidBloc,
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
        builder: (ctx, _) => BlocProvider<BidBloc>.value(
          value: bidBloc,
          child: const BidListScreenTesting(announcementId: 'ann-1'),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (_, state) => Scaffold(
          body: Text('Bid detail ${state.pathParameters['id']}'),
        ),
      ),
      GoRoute(
        path: '/tracking/scan',
        builder: (_, _) => const Scaffold(body: Text('scan')),
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
  });

  late MockBidBloc bidBloc;

  setUp(() {
    bidBloc = MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
  });

  tearDown(() {
    bidBloc.close();
  });

  // ── Titre statique « Demandes » ─────────────────────────────────────────────

  testWidgets('le titre de l\'app bar est « Demandes »', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'ACCEPTED')]));
    await tester.pumpAndSettle();

    expect(find.text('Demandes'), findsOneWidget);
  });

  testWidgets('le titre devient « Colis » quand title = Colis', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, title: 'Colis');
    ctrl.add(BidListLoaded([_makeBid(status: 'ACCEPTED')]));
    await tester.pumpAndSettle();

    expect(find.text('Colis'), findsOneWidget);
    expect(find.text('Demandes'), findsNothing);
  });

  // ── Bouton « À traiter » ────────────────────────────────────────────────────

  testWidgets(
      'bouton « À traiter » visible avec badge quand ≥ 1 demande en attente',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'PAYMENT_ESCROWED', id: 'p1'),
      _makeBid(status: 'ACCEPTED', id: 'a1'),
      _makeBid(status: 'IN_TRANSIT', id: 'a2'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('À traiter'), findsOneWidget);
    // Badge compteur = 1 demande en attente.
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('bouton « À traiter » absent quand 0 demande en attente',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'a1'),
      _makeBid(status: 'IN_TRANSIT', id: 'a2'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('À traiter'), findsNothing);
  });

  testWidgets('tap « À traiter » navigue vers l\'écran pending', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'PENDING', id: 'p1'),
      _makeBid(status: 'ACCEPTED', id: 'a1'),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('À traiter'));
    await tester.pumpAndSettle();

    expect(find.text('pending screen'), findsOneWidget);
  });

  // ── Liste « Acceptées » — statuts ───────────────────────────────────────────

  testWidgets('les 7 statuts post-acceptation s\'affichent avec le bon libellé',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc);
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

    expect(find.text('Tous (7)'), findsOneWidget);
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

    await _pump(tester, bidBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1'),
      _makeBid(
          status: 'CANCELLED',
          id: 'b2',
          rejectionReason: 'TRAVELER_NO_RESPONSE'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Tous (1)'), findsOneWidget);
    expect(find.text('Annulé'), findsNothing);
    expect(find.byType(DonyAvatar), findsOneWidget);
  });

  // ── Recherche ───────────────────────────────────────────────────────────────

  testWidgets('la recherche par nom filtre la liste', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1'),
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

    await _pump(tester, bidBloc);
    ctrl.add(BidListLoaded([
      _makeBid(
          status: 'ACCEPTED',
          id: 'b1',
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

    await _pump(tester, bidBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1'),
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

    await _pump(tester, bidBloc);
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

    await _pump(tester, bidBloc);
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

    await _pump(tester, bidBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1'),
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

    await _pump(tester, bidBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1'),
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

  // ── État BidLoading ─────────────────────────────────────────────────────────

  testWidgets('BidLoading affiche un spinner centré', (tester) async {
    when(() => bidBloc.state).thenReturn(BidLoading());
    whenListen(bidBloc, Stream<BidState>.fromIterable([BidLoading()]),
        initialState: BidLoading());

    await _pump(tester, bidBloc);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // ── État BidError dans le body ──────────────────────────────────────────────

  testWidgets('BidError dans body affiche message et bouton Réessayer',
      (tester) async {
    const error = NetworkException('Erreur réseau');
    when(() => bidBloc.state).thenReturn(BidError(error));
    whenListen(bidBloc, Stream<BidState>.fromIterable([BidError(error)]),
        initialState: BidError(error));

    await _pump(tester, bidBloc);
    await tester.pump();

    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('bouton Réessayer dans BidListErrorView redispatche BidListRequested',
      (tester) async {
    const error = NetworkException('Erreur réseau');
    when(() => bidBloc.state).thenReturn(BidError(error));
    final bidCtrl = StreamController<BidState>.broadcast();
    whenListen(bidBloc, bidCtrl.stream, initialState: BidError(error));
    addTearDown(bidCtrl.close);

    await _pump(tester, bidBloc);
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
      departureCityCode: 'CDG',
      arrivalCityCode: 'DKR',
    );
    ctrl.add(BidListLoaded([_makeBid(status: 'ACCEPTED')]));
    await tester.pumpAndSettle();

    expect(find.textContaining('CDG → DKR'), findsOneWidget);
  });

  testWidgets('subtitle avec date de départ s\'affiche', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(
      tester,
      bidBloc,
      departureCityCode: 'CDG',
      arrivalCityCode: 'DKR',
      departureDate: DateTime(2026, 6, 15),
    );
    ctrl.add(BidListLoaded([_makeBid(status: 'ACCEPTED')]));
    await tester.pumpAndSettle();

    expect(find.textContaining('CDG → DKR'), findsOneWidget);
    expect(find.textContaining('juin'), findsOneWidget);
  });

  // ── Empty state liste acceptées ─────────────────────────────────────────────

  testWidgets('liste acceptées vide → « Aucune demande acceptée »',
      (tester) async {
    // État chargé fourni dès le 1er frame (comme initialState) : l'empty state
    // (mascotte animée) se rend une fois et un seul pump(durée) draine
    // l'animation flutter_animate sans laisser de timer en vol après dispose.
    final loaded = BidListLoaded([_makeBid(status: 'PENDING')]);
    when(() => bidBloc.state).thenReturn(loaded);
    whenListen(bidBloc, const Stream<BidState>.empty(), initialState: loaded);

    await _pump(tester, bidBloc);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Aucune demande acceptée'), findsOneWidget);
  });

  // ── BidNotFound ─────────────────────────────────────────────────────────────

  testWidgets('BidNotFound → navigue vers /home quand non poppable',
      (tester) async {
    final bidCtrl = StreamController<BidState>.broadcast();
    when(() => bidBloc.state).thenReturn(BidInitial());
    whenListen(bidBloc, bidCtrl.stream, initialState: BidInitial());
    addTearDown(bidCtrl.close);

    await _pumpFromRoot(tester, bidBloc);

    bidCtrl.add(BidNotFound());
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('BidNotFound → pop quand canPop est vrai', (tester) async {
    await initializeDateFormatting('fr_FR');
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bidCtrl = StreamController<BidState>.broadcast();
    when(() => bidBloc.state).thenReturn(BidInitial());
    whenListen(bidBloc, bidCtrl.stream, initialState: BidInitial());
    addTearDown(bidCtrl.close);

    final router = GoRouter(
      initialLocation: '/parent',
      routes: [
        GoRoute(
          path: '/parent',
          builder: (_, _) => const Scaffold(body: Text('parent')),
          routes: [
            GoRoute(
              path: 'screen',
              builder: (ctx, _) => BlocProvider<BidBloc>.value(
                value: bidBloc,
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

    bidCtrl.add(BidListLoaded([_makeBid(status: 'ACCEPTED')]));
    await tester.pumpAndSettle();

    bidCtrl.add(BidNotFound());
    await tester.pumpAndSettle();

    expect(find.text('parent'), findsOneWidget);
  });

  // ── Navigation via bid card tap ─────────────────────────────────────────────

  testWidgets('tap sur une bid card navigue vers /bids/:id', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'ACCEPTED', id: 'bid-xyz')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Bid detail bid-xyz'), findsOneWidget);
  });

  // ── Scanner chip button ─────────────────────────────────────────────────────

  testWidgets('tap sur Scanner navigue vers /tracking/scan', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'ACCEPTED')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scanner'));
    await tester.pumpAndSettle();

    expect(find.text('scan'), findsOneWidget);
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

    final router = GoRouter(
      initialLocation: '/parent',
      routes: [
        GoRoute(
          path: '/parent',
          builder: (_, _) => const Scaffold(body: Text('parent')),
          routes: [
            GoRoute(
              path: 'screen',
              builder: (ctx, _) => BlocProvider<BidBloc>.value(
                value: bidBloc,
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

    bidCtrl.add(BidListLoaded([_makeBid(status: 'ACCEPTED')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();

    expect(find.text('parent'), findsOneWidget);
  });
}
