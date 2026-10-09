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

import '../../../../helpers/l10n_test_helpers.dart';

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

  // Régression staging : un bid accepté en mobile money passe en
  // AWAITING_PAYMENT (30 min pour le séquestre côté expéditeur). Avant le
  // fix, isAcceptedTabBid le filtrait purement et simplement de cette
  // section (colis invisible) ; une fois rendu visible, _statusMeta
  // retombait sur le défaut et affichait la chaîne brute anglaise.
  testWidgets('AWAITING_PAYMENT (mobile money) → colis visible avec le libellé '
      'français « Paiement en attente », jamais la chaîne brute', (
    tester,
  ) async {
    stub(BidListLoaded([_makeBid(status: 'AWAITING_PAYMENT', id: 'b1')]));

    await _pump(tester, bidBloc);
    await tester.pump();

    expect(find.text('Paiement en attente'), findsOneWidget);
    expect(find.text('AWAITING_PAYMENT'), findsNothing);
    expect(find.byType(DonyEmptyState), findsNothing);
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

  group('traductions', () {
    testWidgets('en anglais : titre, état vide et statut traduits', (
      tester,
    ) async {
      useEnglish();
      stub(BidListLoaded(const []));

      await _pump(tester, bidBloc);
      await tester.pump();

      expect(find.text('Parcels on this trip'), findsOneWidget);
      expect(find.text('No parcels on board'), findsOneWidget);
      expect(find.text('Colis dans le trajet'), findsNothing);
    });

    testWidgets('en anglais : statut « Payment pending »', (tester) async {
      useEnglish();
      stub(BidListLoaded([_makeBid(status: 'AWAITING_PAYMENT', id: 'b1')]));

      await _pump(tester, bidBloc);
      await tester.pump();

      expect(find.text('Payment pending'), findsOneWidget);
    });
  });

  // ── Résumé de tête (FLUTTER-GS) ───────────────────────────────────────────
  group('résumé des colis', () {
    String summaryText(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('trip-parcels-summary')))
        .textSpan!
        .toPlainText();

    test('répartition par étape du cycle réel', () {
      final c = tripParcelsCounts([
        _makeBid(status: 'HANDED_OVER'),
        _makeBid(status: 'IN_TRANSIT'),
        _makeBid(status: 'ACCEPTED'),
        _makeBid(status: 'AWAITING_PAYMENT'),
        _makeBid(status: 'ARRIVED'),
        _makeBid(status: 'COMPLETED'),
        _makeBid(status: 'COMPLETED'),
        _makeBid(status: 'NO_SHOW'),
      ]);
      expect(c.inTransit, 2);
      expect(c.toCollect, 1);
      expect(c.arrived, 1);
      expect(c.delivered, 2);
    });

    testWidgets('pluriels FR, ordre fixe, segments vides omis', (tester) async {
      stub(
        BidListLoaded([
          _makeBid(status: 'IN_TRANSIT', id: 'b1'),
          _makeBid(status: 'IN_TRANSIT', id: 'b2'),
          _makeBid(status: 'HANDED_OVER', id: 'b3'),
          _makeBid(status: 'ACCEPTED', id: 'b4'),
          _makeBid(status: 'COMPLETED', id: 'b5'),
          _makeBid(status: 'COMPLETED', id: 'b6'),
        ]),
      );

      await _pump(tester, bidBloc);
      await tester.pump();

      expect(
        summaryText(tester),
        '3 colis en route  ·  1 à récupérer  ·  2 livrés',
      );
      expect(
        find.bySemanticsLabel('3 colis en route · 1 à récupérer · 2 livrés'),
        findsOneWidget,
      );
    });

    testWidgets('singuliers FR et colis arrivé', (tester) async {
      stub(
        BidListLoaded([
          _makeBid(status: 'ARRIVED', id: 'b1'),
          _makeBid(status: 'COMPLETED', id: 'b2'),
        ]),
      );

      await _pump(tester, bidBloc);
      await tester.pump();

      expect(summaryText(tester), '1 arrivé  ·  1 livré');
    });

    testWidgets('anglais : pluriels ICU', (tester) async {
      useEnglish();
      stub(
        BidListLoaded([
          _makeBid(status: 'IN_TRANSIT', id: 'b1'),
          _makeBid(status: 'ACCEPTED', id: 'b2'),
          _makeBid(status: 'ACCEPTED', id: 'b3'),
        ]),
      );

      await _pump(tester, bidBloc);
      await tester.pump();

      expect(summaryText(tester), '1 parcel in transit  ·  2 to pick up');
    });

    testWidgets('chiffres tabulaires', (tester) async {
      stub(BidListLoaded([_makeBid(status: 'ACCEPTED', id: 'b1')]));

      await _pump(tester, bidBloc);
      await tester.pump();

      final root =
          tester
                  .widget<Text>(find.byKey(const Key('trip-parcels-summary')))
                  .textSpan!
              as TextSpan;
      final number = root.children!.whereType<TextSpan>().firstWhere(
        (s) => s.text == '1',
      );
      expect(
        number.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    testWidgets('toujours visible quand un filtre est actif', (tester) async {
      stub(
        BidListLoaded([
          _makeBid(status: 'ACCEPTED', id: 'b1'),
          _makeBid(status: 'COMPLETED', id: 'b2'),
        ]),
      );

      await _pump(tester, bidBloc);
      await tester.pump();
      await tester.tap(find.text('Livré').first);
      await tester.pump();

      expect(summaryText(tester), '1 à récupérer  ·  1 livré');
    });

    testWidgets('que des clôturés → pas de résumé', (tester) async {
      stub(BidListLoaded([_makeBid(status: 'NO_SHOW', id: 'b1')]));

      await _pump(tester, bidBloc);
      await tester.pump();

      expect(find.byKey(const Key('trip-parcels-summary')), findsNothing);
    });
  });
}
