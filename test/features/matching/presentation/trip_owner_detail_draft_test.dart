// Task 5 (trip-draft-status) — écran détail propriétaire d'un trajet.
//
// Couvre :
//  - Bannière « brouillon » + tuile « Publier » visibles uniquement pour un
//    trajet DRAFT (jamais pour un trajet ACTIVE).
//  - Tap sur « Publier » → dispatch AnnouncementPublishRequested(id).
//  - Gating édition/suppression : un DRAFT à 0 demande reste modifiable ET
//    supprimable (le backend autorise désormais la suppression d'un brouillon).
//
// Pattern de harnais repris de
// test/features/matching/presentation/screens/trip_owner_detail_screen_test.dart
// (MockBloc mocktail + MultiBlocProvider + GoRouter minimal).

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/trip_owner_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _ownerId = 'trav-001';

final _owner = UserModel(
  id: _ownerId,
  roles: const [],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

AnnouncementModel _makeAnnouncement({
  String status = 'ACTIVE',
  int? bidsCount = 0,
}) =>
    AnnouncementModel(
      id: 'ann-trip-001',
      travelerId: _ownerId,
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2027, 7, 1),
      availableKg: 10,
      totalKg: 23,
      pricePerKg: 8,
      status: status,
      bidsCount: bidsCount,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester, {
  required _MockAnnouncementBloc annBloc,
  required _MockBidBloc bidBloc,
  required _MockCancellationBloc cancelBloc,
  required _MockAuthBloc authBloc,
  AnnouncementModel? initial,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
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
            BlocProvider<CancellationBloc>.value(value: cancelBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          child: TripOwnerDetailScreen(
            announcementId: 'ann-trip-001',
            initial: initial,
          ),
        ),
      ),
      GoRoute(
        path: '/kyc/status',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('KYC status'))),
      ),
      GoRoute(
        path: '/trips/create',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Créer / modifier'))),
      ),
      GoRoute(
        path: '/profile/upgrade-to-pro',
        builder: (_, __) => const Scaffold(body: Center(child: Text('Upgrade'))),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _MockAnnouncementBloc annBloc;
  late _MockBidBloc bidBloc;
  late _MockCancellationBloc cancelBloc;
  late _MockAuthBloc authBloc;
  late _MockAnalyticsService analytics;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(AnnouncementDetailRequested(''));
  });

  setUp(() {
    annBloc = _MockAnnouncementBloc();
    bidBloc = _MockBidBloc();
    cancelBloc = _MockCancellationBloc();
    authBloc = _MockAuthBloc();
    analytics = _MockAnalyticsService();

    when(() => analytics.logEvent(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});
    when(() => analytics.logScreen(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});

    when(() => bidBloc.state).thenReturn(BidListLoaded(const []));
    whenListen(
      bidBloc,
      Stream<BidState>.value(BidListLoaded(const [])),
      initialState: BidListLoaded(const []),
    );
    when(() => cancelBloc.state).thenReturn(CancellationInitial());
    whenListen(cancelBloc, const Stream<CancellationState>.empty(),
        initialState: CancellationInitial());

    when(() => authBloc.state).thenReturn(AuthAuthenticated(_owner));
    whenListen(authBloc, const Stream<AuthState>.empty(),
        initialState: AuthAuthenticated(_owner));

    when(() => annBloc.add(any())).thenReturn(null);

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    annBloc.close();
    bidBloc.close();
    cancelBloc.close();
    authBloc.close();
  });

  testWidgets(
      'affiche la bannière brouillon et le bouton Publier pour un DRAFT',
      (tester) async {
    final announcement = _makeAnnouncement(status: 'DRAFT');
    when(() => annBloc.state)
        .thenReturn(AnnouncementDetailLoaded(announcement));
    whenListen(
      annBloc,
      Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
      initialState: AnnouncementDetailLoaded(announcement),
    );

    await _pump(tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc);
    await tester.pumpAndSettle();

    expect(find.textContaining('brouillon'), findsWidgets);
    expect(find.text('Publier'), findsOneWidget);
  });

  testWidgets(
      'pas de bannière ni de bouton Publier pour un trajet ACTIVE',
      (tester) async {
    final announcement = _makeAnnouncement(status: 'ACTIVE');
    when(() => annBloc.state)
        .thenReturn(AnnouncementDetailLoaded(announcement));
    whenListen(
      annBloc,
      Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
      initialState: AnnouncementDetailLoaded(announcement),
    );

    await _pump(tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc);
    await tester.pumpAndSettle();

    expect(find.text('Publier'), findsNothing);
    expect(find.textContaining('brouillon'), findsNothing);
  });

  testWidgets('taper Publier dispatch AnnouncementPublishRequested',
      (tester) async {
    final announcement = _makeAnnouncement(status: 'DRAFT');
    when(() => annBloc.state)
        .thenReturn(AnnouncementDetailLoaded(announcement));
    whenListen(
      annBloc,
      Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
      initialState: AnnouncementDetailLoaded(announcement),
    );

    await _pump(tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Publier'));
    await tester.pump();

    verify(
      () => annBloc.add(
        any(
          that: predicate<AnnouncementEvent>(
            (e) =>
                e is AnnouncementPublishRequested &&
                e.id == announcement.id,
            'AnnouncementPublishRequested(${announcement.id})',
          ),
        ),
      ),
    ).called(1);
  });

  testWidgets(
      'un DRAFT à 0 demande reste modifiable et supprimable (tuiles actives)',
      (tester) async {
    final announcement =
        _makeAnnouncement(status: 'DRAFT', bidsCount: 0);
    when(() => annBloc.state)
        .thenReturn(AnnouncementDetailLoaded(announcement));
    whenListen(
      annBloc,
      Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
      initialState: AnnouncementDetailLoaded(announcement),
    );

    await _pump(tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc);
    await tester.pumpAndSettle();

    // Tuile « Modifier » tappable (pas grisée par un Opacity 0.4 wrapper).
    final modifierTooltip = find.ancestor(
      of: find.text('Modifier'),
      matching: find.byType(Tooltip),
    );
    expect(modifierTooltip, findsNothing,
        reason: 'Modifier doit être actif (pas de tooltip disabled) pour un DRAFT à 0 demande');

    // Tuile « Supprimer » présente (le backend autorise la suppression d'un DRAFT).
    expect(find.text('Supprimer'), findsOneWidget);
  });

  testWidgets(
      'l\'écran affiche le badge « Brouillon » dans le détail pour un DRAFT',
      (tester) async {
    final announcement = _makeAnnouncement(status: 'DRAFT');
    when(() => annBloc.state)
        .thenReturn(AnnouncementDetailLoaded(announcement));
    whenListen(
      annBloc,
      Stream<AnnouncementState>.value(AnnouncementDetailLoaded(announcement)),
      initialState: AnnouncementDetailLoaded(announcement),
    );

    await _pump(tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc);
    await tester.pumpAndSettle();

    expect(find.textContaining('BROUILLON'), findsOneWidget);
  });

  testWidgets(
      'après publication (AnnouncementPublished sans reload), la bannière '
      'brouillon et la tuile Publier disparaissent', (tester) async {
    final draft = _makeAnnouncement(status: 'DRAFT');
    final published = _makeAnnouncement(status: 'ACTIVE');

    // État initial : DetailLoaded en DRAFT, ET widget.initial passé en DRAFT
    // (comme lors d'une navigation depuis la liste avec `extra:`), pour
    // reproduire le repli sur `widget.initial` figé si le rechargement
    // déclenché après publication n'aboutit pas.
    when(() => annBloc.state).thenReturn(AnnouncementDetailLoaded(draft));
    final controller = StreamController<AnnouncementState>();
    whenListen(
      annBloc,
      controller.stream,
      initialState: AnnouncementDetailLoaded(draft),
    );
    addTearDown(controller.close);

    await _pump(tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
        initial: draft);
    await tester.pumpAndSettle();

    expect(find.textContaining('brouillon'), findsWidgets);
    expect(find.text('Publier'), findsOneWidget);

    // Le bloc émet l'état intermédiaire AnnouncementPublished (ACTIVE), sans
    // que le AnnouncementDetailLoaded du reload ne suive (ex. erreur réseau
    // transitoire sur AnnouncementDetailRequested). Cet état déclenche aussi
    // la navigation plein écran vers DonySuccessScreen — on laisse
    // l'animation de route se terminer avant d'inspecter l'écran sous-jacent.
    controller.add(AnnouncementPublished(published));
    await tester.pumpAndSettle();

    expect(find.textContaining('brouillon'), findsNothing);
    expect(find.text('Publier'), findsNothing);
    expect(find.textContaining('BROUILLON'), findsNothing);
  });

  testWidgets(
      'AnnouncementPublished affiche un DonySuccessScreen plein écran ; '
      'tap sur Continuer revient au détail déjà rafraîchi', (tester) async {
    final draft = _makeAnnouncement(status: 'DRAFT');
    final published = _makeAnnouncement(status: 'ACTIVE');

    when(() => annBloc.state).thenReturn(AnnouncementDetailLoaded(draft));
    final controller = StreamController<AnnouncementState>();
    whenListen(
      annBloc,
      controller.stream,
      initialState: AnnouncementDetailLoaded(draft),
    );
    addTearDown(controller.close);

    await _pump(tester,
        annBloc: annBloc,
        bidBloc: bidBloc,
        cancelBloc: cancelBloc,
        authBloc: authBloc,
        initial: draft);
    await tester.pumpAndSettle();

    controller.add(AnnouncementPublished(published));
    await tester.pumpAndSettle();

    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Trajet publié !'), findsOneWidget);

    verify(
      () => annBloc.add(
        any(
          that: predicate<AnnouncementEvent>(
            (e) =>
                e is AnnouncementDetailRequested &&
                e.id == 'ann-trip-001',
            'AnnouncementDetailRequested(ann-trip-001)',
          ),
        ),
      ),
    ).called(1);

    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.byType(DonySuccessScreen), findsNothing);
    expect(find.byType(TripOwnerDetailScreen), findsOneWidget);
  });
}
