import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
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

// ── Fixture ───────────────────────────────────────────────────────────────────

AnnouncementModel _makeAnnouncement({
  String status = 'ACTIVE',
  int? bidsCount,
  int confirmedParcelCount = 0,
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
      createdAt: DateTime(2026, 6),
      updatedAt: DateTime(2026, 6),
    );

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<GoRouter> _pump(
  WidgetTester tester, {
  required _MockAnnouncementBloc annBloc,
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
        builder: (ctx, _) => BlocProvider<AnnouncementBloc>.value(
          value: annBloc,
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

  setUp(() {
    annBloc = _MockAnnouncementBloc();
    when(() => annBloc.state)
        .thenReturn(AnnouncementDetailLoaded(_makeAnnouncement()));
  });

  tearDown(() => annBloc.close());

  testWidgets('(a) ACTIVE bidsCount=0 → Demandes, Colis, Modifier actif, Supprimer',
      (tester) async {
    final a = _makeAnnouncement(bidsCount: 0);

    await _pump(tester, annBloc: annBloc, a: a, isOwner: true);

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

    await _pump(tester, annBloc: annBloc, a: a, isOwner: true);

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

    await _pump(tester, annBloc: annBloc, a: a, isOwner: false);

    expect(find.text('Demandes'), findsNothing);
    expect(find.text('Colis'), findsNothing);
    expect(find.text('Modifier'), findsNothing);
    expect(find.text('Supprimer'), findsNothing);
    expect(find.byType(OwnerActionGrid), findsOneWidget);
  });

  testWidgets('CANCELLED → Supprimer présent, pas de Demandes ni Annuler',
      (tester) async {
    final a = _makeAnnouncement(status: 'CANCELLED', bidsCount: 3);

    await _pump(tester, annBloc: annBloc, a: a, isOwner: true);

    expect(find.text('Supprimer'), findsOneWidget);
    expect(find.text('Demandes'), findsNothing); // non ACTIVE
    expect(find.text('Annuler'), findsNothing);
  });

  testWidgets('tap Demandes → navigue vers /announcements/:id/bids',
      (tester) async {
    final a = _makeAnnouncement(bidsCount: 0);

    await _pump(tester, annBloc: annBloc, a: a, isOwner: true);

    await tester.tap(find.text('Demandes'));
    await tester.pumpAndSettle();

    expect(find.text('BIDS_SCREEN'), findsOneWidget);
  });
}
