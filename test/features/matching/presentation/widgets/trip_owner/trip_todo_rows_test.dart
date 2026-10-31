// Lignes « autres choses à traiter » de l'écran du trajet (« Je pars »,
// « Ajouter la carte ») : une carte, une ligne par tuile hors `requests`,
// icône, titre, résumé, chevron, tap qui ouvre le sheet de la tuile
// (openTripTodoSheet inchangé), mesure `bid_detail_todo_tile_shown`, FR et
// EN à 360 dp × 1,3.
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_live.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_rows.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'trip_answer_harness.dart';

const _ready = StripeAccountReady(
  ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
);

const _summary = TripParcelsSummary(
  count: 1,
  totalKg: 3,
  netAmount: 30,
  currency: 'EUR',
);

/// Trajet en espèces seules, compte de paiement selon [stripe] : tuile
/// « carte ». [depart] : colis remis et suivi ouvert, tuile « Je pars »
/// (le colis remis verrouille la modification : jamais avec « carte »).
TripTodoLiveData _live({
  String status = 'ACTIVE',
  bool cash = false,
  bool depart = false,
  StripeAccountState stripe = const StripeAccountInitial(),
  List<BidModel>? bids = const [],
}) => TripTodoLiveData(
  trip: AnnouncementModel(
    id: 'trip-1',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(2026, 11, 12),
    availableKg: 20,
    totalKg: 20,
    status: status,
    acceptedPaymentMethods: cash
        ? const {BidPaymentMethod.cash}
        : const {BidPaymentMethod.stripe},
    trackingActive: depart,
    parcelsSummary: depart ? _summary : null,
    createdAt: DateTime(2026, 10),
    updatedAt: DateTime(2026, 10),
  ),
  bids: bids,
  departed: false,
  stripe: stripe,
);

void main() {
  late AnswerHarness h;
  late List<TripTodoTile> opened;
  late TodoTileViewLog views;

  setUpAll(() async {
    AnswerHarness.registerFallbacks();
    await loadAppFonts();
  });

  setUp(() async {
    h = AnswerHarness();
    await h.setUp();
    opened = [];
    views = TodoTileViewLog();
  });

  tearDown(() => h.tearDown());

  Future<void> pumpRows(
    WidgetTester tester,
    TripTodoLiveData live, {
    Locale locale = const Locale('fr'),
    double textScale = 1,
    Size size = const Size(400, 1000),
    ValueChanged<TripTodoTile>? onOpen,
  }) => h
      .pump(
        tester,
        trip: live.trip,
        bids: live.bids,
        locale: locale,
        textScale: textScale,
        size: size,
        body: (context) => TripTodoRows(
          live: live,
          views: views,
          onOpen: onOpen ?? opened.add,
        ),
      )
      .then((_) {});

  test('tripTodoRowTiles : jamais la tuile requests', () {
    final withRequests = _live(cash: true, bids: [answerBid('r1')]);
    expect(withRequests.tiles, [TripTodoTile.requests, TripTodoTile.card]);
    expect(tripTodoRowTiles(withRequests), [TripTodoTile.card]);
    expect(tripTodoRowTiles(_live(bids: [answerBid('r1')])), isEmpty);
    expect(tripTodoRowTiles(_live(depart: true)), [TripTodoTile.depart]);
  });

  testWidgets('aucune ligne : rien', (tester) async {
    await pumpRows(tester, _live(bids: [answerBid('r1')]));
    expect(find.byKey(const Key('trip-todo-rows')), findsNothing);
  });

  testWidgets('« Je pars » : icône, titre, résumé, chevron ; tap → onOpen', (
    tester,
  ) async {
    await pumpRows(tester, _live(depart: true));
    expect(find.byKey(const Key('trip-todo-rows')), findsOneWidget);
    expect(find.text('Je pars'), findsOneWidget);
    final l = tester.element(find.byType(TripTodoRows)).l10n;
    expect(find.text(l.tripTodoDepartSummary), findsOneWidget);
    final icons = tester
        .widgetList<DonyIcon>(find.byType(DonyIcon))
        .map((i) => i.name);
    expect(icons, containsAll(['plane', 'chevron-right']));
    await tester.tap(find.byKey(const Key('trip_owner-todo-depart')));
    expect(opened, [TripTodoTile.depart]);
  });

  testWidgets('résumés et titres existants (tripTodoTitle/Summary)', (
    tester,
  ) async {
    await pumpRows(tester, _live(cash: true, stripe: _ready));
    final context = tester.element(find.byType(TripTodoRows));
    final l = context.l10n;
    expect(
      find.text(tripTodoTitle(l, TripTodoTile.card, cardReady: true)),
      findsOneWidget,
    );
    expect(
      find.text(
        tripTodoSummary(l, TripTodoTile.card, pendingCount: 0, cardReady: true),
      ),
      findsOneWidget,
    );
    expect(find.text('Ajouter la carte à ce trajet'), findsOneWidget);
  });

  testWidgets('compte pas prêt : « Activer les paiements par carte »', (
    tester,
  ) async {
    await pumpRows(tester, _live(cash: true));
    expect(find.text('Activer les paiements par carte'), findsOneWidget);
    await tester.tap(find.byKey(const Key('trip_owner-todo-card')));
    expect(opened, [TripTodoTile.card]);
  });

  testWidgets('tap : openTripTodoSheet inchangé (sheet de la tuile)', (
    tester,
  ) async {
    late BuildContext screen;
    await h.pump(
      tester,
      trip: _live(cash: true).trip,
      bids: const [],
      body: (context) {
        screen = context;
        final live = _live(cash: true);
        return TripTodoRows(
          live: live,
          views: views,
          onOpen: (tile) => openTripTodoSheet(screen, live.trip, tile),
        );
      },
    );
    await tester.tap(find.byKey(const Key('trip_owner-todo-card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip-todo-card-content')), findsOneWidget);
    verify(
      () => h.backend.capture(AnalyticsEvents.bidDetailTileOpened, {
        'tile': 'card',
        'role': 'trip_owner',
        'source': 'tile',
      }),
    ).called(1);
  });

  testWidgets('mesure : une fois par tuile et statut', (tester) async {
    await pumpRows(tester, _live(depart: true));
    await tester.pump();
    verify(
      () => h.backend.capture(AnalyticsEvents.bidDetailTodoTileShown, {
        'tile': 'depart',
        'role': 'trip_owner',
        'status': 'ACTIVE',
      }),
    ).called(1);
  });

  testWidgets('anglais', (tester) async {
    await pumpRows(tester, _live(depart: true), locale: const Locale('en'));
    expect(find.text("I'm leaving"), findsOneWidget);
  });

  for (final locale in const [Locale('fr'), Locale('en')]) {
    testWidgets('${locale.languageCode} à 360 dp × 1,3 : aucune exception', (
      tester,
    ) async {
      await pumpRows(
        tester,
        _live(cash: true),
        locale: locale,
        textScale: 1.3,
        size: const Size(360, 1000),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('trip_owner-todo-card'))).height,
        greaterThanOrEqualTo(56),
      );
    });
  }
}
