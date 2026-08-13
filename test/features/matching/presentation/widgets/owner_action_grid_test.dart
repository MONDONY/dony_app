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

// ── Fixtures ──────────────────────────────────────────────────────────────────

AnnouncementModel _makeAnnouncement({
  String status = 'ACTIVE',
  int? bidsCount,
  int confirmedParcelCount = 0,
  int pendingBidCount = 0,
}) => AnnouncementModel(
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

Future<void> _pump(
  WidgetTester tester, {
  required _MockAnnouncementBloc annBloc,
  required _MockBidBloc bidBloc,
  required AnnouncementModel a,
  required bool isOwner,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

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
            child: OwnerActionGrid(a: a, isOwner: isOwner),
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
    MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _MockAnnouncementBloc annBloc;
  late _MockBidBloc bidBloc;

  setUp(() {
    annBloc = _MockAnnouncementBloc();
    when(
      () => annBloc.state,
    ).thenReturn(AnnouncementDetailLoaded(_makeAnnouncement()));
    bidBloc = _MockBidBloc();
    // Par défaut : liste chargée vide → aucune demande, aucun colis.
    when(() => bidBloc.state).thenReturn(BidListLoaded(const []));
  });

  tearDown(() {
    annBloc.close();
    bidBloc.close();
  });

  // ── Gating Modifier / Supprimer / Annuler ──────────────────────────────────

  testWidgets('isOwner:false → SizedBox.shrink (aucune tuile)', (tester) async {
    await _pump(
      tester,
      annBloc: annBloc,
      bidBloc: bidBloc,
      a: _makeAnnouncement(),
      isOwner: false,
    );

    expect(find.text('Demandes'), findsNothing);
    expect(find.text('Colis'), findsNothing);
    expect(find.text('Modifier'), findsNothing);
    expect(find.byType(OwnerActionGrid), findsOneWidget);
  });

  testWidgets('ACTIVE bidsCount=0 → Modifier actif + Supprimer (pas Annuler)', (
    tester,
  ) async {
    await _pump(
      tester,
      annBloc: annBloc,
      bidBloc: bidBloc,
      a: _makeAnnouncement(bidsCount: 0),
      isOwner: true,
    );

    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Dépublier'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    expect(find.text('Annuler'), findsNothing);
    // Modifier actif → pas de tooltip de désactivation.
    expect(find.byTooltip("Modifiable tant qu'aucune demande"), findsNothing);
  });

  testWidgets(
    'ACTIVE bidsCount=2 → Modifier désactivé + Annuler (pas Supprimer)',
    (tester) async {
      await _pump(
        tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        a: _makeAnnouncement(bidsCount: 2),
        isOwner: true,
      );

      expect(
        find.byTooltip("Modifiable tant qu'aucune demande"),
        findsOneWidget,
      );
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Dépublier'), findsNothing);
      expect(find.text('Supprimer'), findsNothing);
    },
  );

  testWidgets('CANCELLED → Supprimer présent, pas d\'Annuler', (tester) async {
    await _pump(
      tester,
      annBloc: annBloc,
      bidBloc: bidBloc,
      a: _makeAnnouncement(status: 'CANCELLED', bidsCount: 3),
      isOwner: true,
    );

    expect(find.text('Supprimer'), findsOneWidget);
    expect(find.text('Annuler'), findsNothing);
  });

  // ── Bouton Demandes → écran « À traiter » ──────────────────────────────────

  testWidgets('Demandes actif (demande en attente) → écran À traiter', (
    tester,
  ) async {
    when(
      () => bidBloc.state,
    ).thenReturn(BidListLoaded([_makeBid(status: 'PENDING')]));

    await _pump(
      tester,
      annBloc: annBloc,
      bidBloc: bidBloc,
      a: _makeAnnouncement(),
      isOwner: true,
    );

    await tester.tap(find.text('Demandes'));
    await tester.pumpAndSettle();

    expect(find.text('PENDING_SCREEN'), findsOneWidget);
  });

  testWidgets('Demandes désactivé sans demande en attente (tap sans effet)', (
    tester,
  ) async {
    await _pump(
      tester,
      annBloc: annBloc,
      bidBloc: bidBloc,
      a: _makeAnnouncement(),
      isOwner: true,
    );

    expect(find.byTooltip('Aucune demande à traiter'), findsOneWidget);

    await tester.tap(find.text('Demandes'));
    await tester.pumpAndSettle();

    expect(find.text('PENDING_SCREEN'), findsNothing);
  });

  // ── Bouton Colis → écran des colis ─────────────────────────────────────────

  testWidgets('Colis actif (colis embarqué) → écran des colis', (tester) async {
    when(
      () => bidBloc.state,
    ).thenReturn(BidListLoaded([_makeBid(status: 'ACCEPTED')]));

    await _pump(
      tester,
      annBloc: annBloc,
      bidBloc: bidBloc,
      a: _makeAnnouncement(),
      isOwner: true,
    );

    await tester.tap(find.text('Colis'));
    await tester.pumpAndSettle();

    expect(find.text('BIDS_SCREEN'), findsOneWidget);
  });

  testWidgets('Colis désactivé sans colis (tap sans effet)', (tester) async {
    await _pump(
      tester,
      annBloc: annBloc,
      bidBloc: bidBloc,
      a: _makeAnnouncement(),
      isOwner: true,
    );

    expect(find.byTooltip('Aucun colis embarqué'), findsOneWidget);

    await tester.tap(find.text('Colis'));
    await tester.pumpAndSettle();

    expect(find.text('BIDS_SCREEN'), findsNothing);
  });
}
