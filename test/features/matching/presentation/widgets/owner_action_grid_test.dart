import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/owner_action_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

// ── Fixture ───────────────────────────────────────────────────────────────────

AnnouncementModel _makeAnnouncement({
  String status = 'ACTIVE',
  int? bidsCount,
  int confirmedParcelCount = 0,
  int pendingBidCount = 0,
}) =>
    AnnouncementModel(
      id: 'ann-001',
      travelerId: 'trav-001',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 7),
      availableKg: 10,
      totalKg: 23,
      pricePerKg: 8,
      status: status,
      bidsCount: bidsCount ?? 0,
      confirmedParcelCount: confirmedParcelCount,
      pendingBidCount: pendingBidCount,
      createdAt: DateTime(2026, 6),
      updatedAt: DateTime(2026, 6),
    );

BidModel _makeBid({required String status, String id = 'bid-1'}) => BidModel(
      id: id,
      announcementId: 'ann-001',
      senderId: 'sender-1',
      senderName: 'Moussa Traoré',
      weightKg: 3,
      contentCategory: 'Vêtements',
      status: status,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<GoRouter> _pump(
  WidgetTester tester, {
  required _MockAnnouncementBloc annBloc,
  required _MockBidBloc bidBloc,
  required AnnouncementModel a,
  required bool isOwner,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final colisKey = GlobalKey();

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => MultiBlocProvider(
          providers: [
            BlocProvider<AnnouncementBloc>.value(value: annBloc),
            BlocProvider<BidBloc>.value(value: bidBloc),
          ],
          child: SingleChildScrollView(
            child: OwnerActionGrid(
              a: a,
              isOwner: isOwner,
              colisSectionKey: colisKey,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/announcements/:id/bids',
        builder: (ctx, _) => const Scaffold(body: Text('BIDS_SCREEN')),
      ),
      GoRoute(
        path: '/announcements/:id/bids/pending',
        builder: (ctx, _) => const Scaffold(body: Text('PENDING_SCREEN')),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return router;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _MockAnnouncementBloc annBloc;
  late _MockBidBloc bidBloc;

  setUp(() {
    annBloc = _MockAnnouncementBloc();
    when(() => annBloc.state)
        .thenReturn(AnnouncementDetailLoaded(_makeAnnouncement()));
    bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidListLoaded(const []));
  });

  tearDown(() {
    annBloc.close();
    bidBloc.close();
  });

  testWidgets('(a) ACTIVE bidsCount=0 → Demandes, Colis, Modifier actif, Supprimer',
      (tester) async {
    final a = _makeAnnouncement(bidsCount: 0);

    await _pump(tester, annBloc: annBloc, bidBloc: bidBloc, a: a, isOwner: true);

    expect(find.text('Demandes'), findsOneWidget);
    expect(find.text('Colis'), findsOneWidget);
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    // Annuler ne doit pas apparaître (la suppression est possible).
    expect(find.text('Annuler'), findsNothing);
    // Modifier actif → pas de Tooltip de désactivation.
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets(
      '(b) ACTIVE bidsCount=2 → Modifier désactivé (tooltip+opacity), Annuler, badge 2',
      (tester) async {
    final a = _makeAnnouncement(bidsCount: 2);

    await _pump(tester, annBloc: annBloc, bidBloc: bidBloc, a: a, isOwner: true);

    // Modifier désactivé : tooltip présent + tuile sous Opacity 0.4.
    expect(
      find.byTooltip('Modifiable tant qu\'aucune demande'),
      findsOneWidget,
    );
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Modifier'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 0.4);

    // Suppression impossible → tuile Annuler à la place de Supprimer.
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Supprimer'), findsNothing);

    // Badge Demandes affiche bien « 2 ».
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('(c) isOwner:false → SizedBox.shrink (aucune tuile)',
      (tester) async {
    final a = _makeAnnouncement();

    await _pump(tester, annBloc: annBloc, bidBloc: bidBloc, a: a, isOwner: false);

    expect(find.text('Demandes'), findsNothing);
    expect(find.text('Colis'), findsNothing);
    expect(find.text('Modifier'), findsNothing);
    expect(find.text('Supprimer'), findsNothing);
    expect(find.byType(OwnerActionGrid), findsOneWidget);
  });

  testWidgets('CANCELLED → Supprimer présent, pas de Demandes ni Annuler',
      (tester) async {
    final a = _makeAnnouncement(status: 'CANCELLED', bidsCount: 3);

    await _pump(tester, annBloc: annBloc, bidBloc: bidBloc, a: a, isOwner: true);

    expect(find.text('Supprimer'), findsOneWidget);
    expect(find.text('Demandes'), findsNothing); // non ACTIVE
    expect(find.text('Annuler'), findsNothing);
  });

  testWidgets(
      'tap Demandes sans demande en attente → liste /announcements/:id/bids',
      (tester) async {
    final a = _makeAnnouncement(bidsCount: 0);

    await _pump(tester, annBloc: annBloc, bidBloc: bidBloc, a: a, isOwner: true);

    await tester.tap(find.text('Demandes'));
    await tester.pumpAndSettle();

    expect(find.text('BIDS_SCREEN'), findsOneWidget);
  });

  testWidgets(
      'tap Demandes avec une demande en attente (BidBloc) → écran « À traiter »',
      (tester) async {
    final a = _makeAnnouncement(bidsCount: 1);
    when(() => bidBloc.state)
        .thenReturn(BidListLoaded([_makeBid(status: 'PENDING')]));

    await _pump(tester, annBloc: annBloc, bidBloc: bidBloc, a: a, isOwner: true);

    await tester.tap(find.text('Demandes'));
    await tester.pumpAndSettle();

    expect(find.text('PENDING_SCREEN'), findsOneWidget);
  });

  testWidgets(
      'tap Demandes : repli sur pendingBidCount quand les bids ne sont pas chargés',
      (tester) async {
    final a = _makeAnnouncement(bidsCount: 2, pendingBidCount: 2);
    when(() => bidBloc.state).thenReturn(BidLoading());

    await _pump(tester, annBloc: annBloc, bidBloc: bidBloc, a: a, isOwner: true);

    await tester.tap(find.text('Demandes'));
    await tester.pumpAndSettle();

    expect(find.text('PENDING_SCREEN'), findsOneWidget);
  });
}
