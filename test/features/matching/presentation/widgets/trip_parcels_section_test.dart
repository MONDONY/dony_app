import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_empty_state.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcels_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

// ── Fixture ───────────────────────────────────────────────────────────────────

BidModel _makeBid({
  required String status,
  String id = 'bid-00000001',
  String senderName = 'Moussa Traoré',
  String contentCategory = 'Vêtements',
}) => BidModel(
  id: id,
  announcementId: 'ann-1',
  senderId: 'sender-1',
  senderName: senderName,
  weightKg: 3,
  contentCategory: contentCategory,
  status: status,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester, _MockBidBloc bidBloc) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => BlocProvider<BidBloc>.value(
          value: bidBloc,
          child: const Scaffold(
            body: SingleChildScrollView(child: TripParcelsSection()),
          ),
        ),
      ),
      GoRoute(
        path: '/bids/:bidId',
        builder: (_, state) =>
            Scaffold(body: Text('Bid detail ${state.pathParameters['bidId']}')),
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
  late _MockBidBloc bidBloc;
  late _MockAnalyticsService analytics;

  setUp(() {
    bidBloc = _MockBidBloc();
    analytics = _MockAnalyticsService();

    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

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
  });

  void stub(BidState state) {
    when(() => bidBloc.state).thenReturn(state);
    whenListen(bidBloc, Stream<BidState>.value(state), initialState: state);
  }

  testWidgets('liste vide → affiche l\'état vide « Aucun colis embarqué »', (
    tester,
  ) async {
    stub(BidListLoaded(const []));

    await _pump(tester, bidBloc);
    await tester.pump();

    expect(find.byType(DonyEmptyState), findsOneWidget);
    expect(find.text('Aucun colis embarqué'), findsOneWidget);
  });

  testWidgets(
    'seuls les colis embarqués (acceptés) sont affichés, les PENDING masqués',
    (tester) async {
      final accepted = _makeBid(
        status: 'ACCEPTED',
        id: 'bid-accepted',
        senderName: 'Aïssa Camara',
        contentCategory: 'Documents',
      );
      final pending = _makeBid(
        status: 'PENDING',
        id: 'bid-pending',
        senderName: 'Karim Sow',
        contentCategory: 'Électronique',
      );
      stub(BidListLoaded([accepted, pending]));

      await _pump(tester, bidBloc);
      await tester.pump();

      // Le colis accepté est rendu (contenu + expéditeur visibles).
      expect(find.text('Documents'), findsOneWidget);
      expect(find.textContaining('Aïssa Camara'), findsOneWidget);

      // Le colis PENDING n'apparaît pas (filtré par isAcceptedTabBid).
      expect(find.text('Électronique'), findsNothing);
      expect(find.textContaining('Karim Sow'), findsNothing);

      // Aucun état vide quand au moins un colis est embarqué.
      expect(find.byType(DonyEmptyState), findsNothing);
    },
  );

  testWidgets('état de chargement → CircularProgressIndicator', (tester) async {
    stub(BidLoading());

    await _pump(tester, bidBloc);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('≥ 2 statuts → filtre rapide affiché avec compteur « Tous »', (
    tester,
  ) async {
    stub(
      BidListLoaded([
        _makeBid(status: 'ACCEPTED', id: 'b1', contentCategory: 'Documents'),
        _makeBid(
          status: 'IN_TRANSIT',
          id: 'b2',
          contentCategory: 'Électronique',
        ),
        _makeBid(status: 'CANCELLED', id: 'b3', contentCategory: 'Bijoux'),
      ]),
    );

    await _pump(tester, bidBloc);
    await tester.pump();

    expect(find.byType(StatusChipsRow<String?>), findsOneWidget);
    expect(find.text('Tous · 3'), findsOneWidget);
    // Les 3 colis sont visibles tant qu'aucun filtre n'est actif.
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Électronique'), findsOneWidget);
    expect(find.text('Bijoux'), findsOneWidget);
  });

  testWidgets('tap chip statut → filtre la liste sur ce statut', (
    tester,
  ) async {
    stub(
      BidListLoaded([
        _makeBid(status: 'ACCEPTED', id: 'b1', contentCategory: 'Documents'),
        _makeBid(
          status: 'IN_TRANSIT',
          id: 'b2',
          contentCategory: 'Électronique',
        ),
        _makeBid(status: 'CANCELLED', id: 'b3', contentCategory: 'Bijoux'),
      ]),
    );

    await _pump(tester, bidBloc);
    await tester.pump();

    // La chip de filtre « En transit · 1 » est distincte du chip de ligne.
    await tester.tap(find.text('En transit · 1'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Électronique'), findsOneWidget);
    expect(find.text('Documents'), findsNothing);
    expect(find.text('Bijoux'), findsNothing);
  });

  // Régression : sans entrée ARRIVED, _statusMeta retombait sur le défaut et
  // affichait la chaîne brute anglaise « ARRIVED » au voyageur.
  testWidgets('ARRIVED → libellé français « Arrivé », jamais la chaîne brute', (
    tester,
  ) async {
    stub(BidListLoaded([_makeBid(status: 'ARRIVED', id: 'b1')]));

    await _pump(tester, bidBloc);
    await tester.pump();

    expect(find.text('Arrivé'), findsOneWidget);
    expect(find.text('ARRIVED'), findsNothing);
  });

  testWidgets('un seul statut → pas de filtre rapide', (tester) async {
    stub(
      BidListLoaded([
        _makeBid(status: 'ACCEPTED', id: 'b1'),
        _makeBid(status: 'ACCEPTED', id: 'b2', senderName: 'Autre Expéditeur'),
      ]),
    );

    await _pump(tester, bidBloc);
    await tester.pump();

    expect(find.byType(StatusChipsRow<String?>), findsNothing);
  });
}
