// Sheets « Activité du trajet » (Demandes, Colis, Gain) : contenu, réponse
// depuis le sheet des demandes, filtre par statut des colis, retour de fiche
// qui relit l'écran, fermeture seule, mesures (`bid_detail_tile_opened`,
// `trip_parcels_viewed`, `trip_parcels_filtered`), nom du sheet, bouton du
// pied à taille nominale en FR et EN à 360 dp × 1,3.
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_activity_row.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_activity_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'trip_answer_harness.dart';

const _summary = TripParcelsSummary(
  count: 2,
  totalKg: 6,
  netAmount: 84,
  currency: 'EUR',
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late AnswerHarness h;

  setUpAll(() async {
    AnswerHarness.registerFallbacks();
    await loadAppFonts();
  });

  setUp(() async {
    h = AnswerHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  /// Ouvre le sheet [activity] depuis le contexte de l'écran, sous ses blocs
  /// et le scope de réponse. [bids] : colis de l'écran (`null` : liste en
  /// chargement) ; [initialBids] : derniers colis connus passés à
  /// l'ouverture.
  Future<List<AnswerPushedRoute>> open(
    WidgetTester tester,
    TripActivity activity, {
    AnnouncementModel? trip,
    List<BidModel>? bids,
    List<BidModel>? initialBids,
    Locale locale = const Locale('fr'),
    double textScale = 1,
    Size size = const Size(400, 900),
  }) async {
    final t = trip ?? answerTrip(parcelsSummary: _summary);
    final pushed = await h.pump(
      tester,
      trip: t,
      bids: bids,
      locale: locale,
      textScale: textScale,
      size: size,
      body: (context) => TextButton(
        onPressed: () =>
            openTripActivitySheet(context, t, activity, bids: initialBids),
        child: const Text('open-activity'),
      ),
    );
    await tester.tap(find.text('open-activity'));
    await _settle(tester);
    return pushed;
  }

  Finder footer() => find.byKey(const Key('donyBottomSheetFooter'));
  String? sheetName(WidgetTester tester, Finder f) =>
      ModalRoute.of(tester.element(f))?.settings.name;

  group('ouverture', () {
    for (final activity in TripActivity.values) {
      testWidgets('${activity.name} : nom du sheet et mesure d\'ouverture', (
        tester,
      ) async {
        await open(tester, activity, bids: answerRequests(1));
        final content = find.byKey(
          Key('trip-activity-${activity.name}-content'),
        );
        expect(content, findsOneWidget);
        expect(
          sheetName(tester, content),
          '/sheet/trip-owner/activity-${activity.name}',
        );
        verify(
          () => h.backend.capture(AnalyticsEvents.bidDetailTileOpened, {
            'tile': activity.name,
            'role': 'trip_owner',
            'source': 'tile',
          }),
        ).called(1);
      });
    }
  });

  group('Demandes', () {
    Finder accept(String id) => find.byKey(Key('trip-request-accept-$id'));

    testWidgets('une ligne par demande, Refuser et Accepter sous chacune, '
        'sans pied', (tester) async {
      await open(
        tester,
        TripActivity.requests,
        bids: [
          ...answerRequests(3),
          answerBid('a1', status: 'ACCEPTED'),
        ],
      );
      expect(find.text('Demandes à traiter'), findsOneWidget);
      for (final id in ['r1', 'r2', 'r3']) {
        expect(find.byKey(Key('trip-activity-request-$id')), findsOneWidget);
        expect(accept(id), findsOneWidget);
        expect(find.byKey(Key('trip-request-reject-$id')), findsOneWidget);
        // Boutons sous la ligne.
        expect(
          tester.getTopLeft(accept(id)).dy,
          greaterThan(
            tester
                .getBottomLeft(find.byKey(Key('trip-activity-request-$id')))
                .dy,
          ),
        );
      }
      expect(find.byKey(const Key('trip-activity-request-a1')), findsNothing);
      expect(footer(), findsNothing);
    });

    testWidgets('accepter depuis le sheet : la ligne part, le sheet reste, '
        'puis « Aucune demande » après la dernière', (tester) async {
      await open(tester, TripActivity.requests, bids: answerRequests(2));
      await tester.tap(accept('r1'));
      await tester.pump();
      await tester.pump();
      expect((h.answerEvents.single as BidAcceptRequested).bidId, 'r1');
      expect(tester.widget<DonyButton>(accept('r2')).onPressed, isNull);
      h.answerStates.add(BidAccepted(answerBid('r1', status: 'ACCEPTED')));
      await _settle(tester);
      expect(find.byKey(const Key('trip-activity-request-r1')), findsNothing);
      expect(find.byKey(const Key('trip-activity-request-r2')), findsOneWidget);
      expect(h.screenEvents.single, isA<BidListRequested>());

      await tester.tap(accept('r2'));
      await tester.pump();
      await tester.pump();
      h.answerStates.add(BidAccepted(answerBid('r2', status: 'ACCEPTED')));
      await _settle(tester);
      // Trajet ouvert : la case Demandes reste, le sheet aussi.
      expect(
        find.text('Aucune demande à traiter pour le moment.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('liste relue pendant l\'ouverture : les lignes suivent', (
      tester,
    ) async {
      await open(tester, TripActivity.requests, bids: answerRequests(1));
      h.screenStates.add(BidListLoaded(answerRequests(3)));
      await _settle(tester);
      expect(find.byKey(const Key('trip-activity-request-r3')), findsOneWidget);
      // Un rechargement garde les lignes.
      h.screenStates.add(BidLoading());
      await _settle(tester);
      expect(find.byKey(const Key('trip-activity-request-r3')), findsOneWidget);
    });

    testWidgets('trajet parti, dernière demande traitée : le sheet se '
        'ferme seul', (tester) async {
      await open(
        tester,
        TripActivity.requests,
        trip: answerTrip(status: 'IN_PROGRESS'),
        bids: answerRequests(1),
      );
      expect(
        find.byKey(const Key('trip-activity-requests-content')),
        findsOneWidget,
      );
      h.screenStates.add(BidListLoaded(const []));
      await _settle(tester);
      expect(
        find.byKey(const Key('trip-activity-requests-content')),
        findsNothing,
      );
    });

    testWidgets('ligne touchée : sheet fermé, fiche du colis, relecture '
        'silencieuse au retour', (tester) async {
      final pushed = await open(
        tester,
        TripActivity.requests,
        bids: answerRequests(1),
      );
      await tester.tap(find.byKey(const Key('trip-activity-request-r1')));
      await _settle(tester);
      expect(pushed.single.location, '/bids/r1');
      expect(h.screenEvents, isEmpty);
      await tester.tap(find.text('back'));
      await _settle(tester);
      expect(
        find.byKey(const Key('trip-activity-requests-content')),
        findsNothing,
      );
      expect((h.screenEvents.single as BidListRequested).silent, isTrue);
      expect(
        (h.annEvents.single as AnnouncementDetailRequested).silent,
        isTrue,
      );
    });

    testWidgets('liste pas chargée : le nombre servi par la liste des '
        'trajets, sinon un indicateur', (tester) async {
      await open(
        tester,
        TripActivity.requests,
        trip: answerTrip(pendingBidCount: 2),
      );
      expect(find.text('2 demandes attendent votre réponse'), findsOneWidget);
    });

    testWidgets('liste pas chargée et compte inconnu : indicateur, jamais '
        '« aucune »', (tester) async {
      await open(tester, TripActivity.requests);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.text('Aucune demande à traiter pour le moment.'),
        findsNothing,
      );
    });

    testWidgets('anglais', (tester) async {
      await open(
        tester,
        TripActivity.requests,
        bids: const [],
        locale: const Locale('en'),
      );
      expect(find.text('Requests to review'), findsOneWidget);
      expect(find.text('No requests to review for now.'), findsOneWidget);
    });
  });

  group('Colis', () {
    final mixed = [
      answerBid('a1', status: 'ACCEPTED', description: 'Article A'),
      answerBid('t1', status: 'IN_TRANSIT', description: 'Article T'),
      answerBid('a2', status: 'ACCEPTED', description: 'Article B'),
      answerBid('d1', status: 'COMPLETED', description: 'Article D'),
      answerBid('p1', description: 'Demande'),
    ];
    Finder row(String id) => find.byKey(Key('trip-activity-parcel-$id'));

    testWidgets('résumé, puces dès deux statuts, une ligne par colis, '
        'trip_parcels_viewed à l\'ouverture', (tester) async {
      await open(tester, TripActivity.parcels, bids: mixed);
      expect(find.text('Colis dans le trajet'), findsOneWidget);
      expect(find.byKey(const Key('trip-parcels-summary')), findsOneWidget);
      expect(find.byType(StatusChipsRow<String?>), findsOneWidget);
      expect(find.text('Tous · 4'), findsOneWidget);
      for (final id in ['a1', 't1', 'a2', 'd1']) {
        expect(row(id), findsOneWidget);
      }
      expect(row('p1'), findsNothing);
      verify(
        () =>
            h.backend.capture(AnalyticsEvents.tripParcelsViewed, {'count': 4}),
      ).called(1);
      // Une relecture n'en réémet pas.
      h.screenStates.add(BidListLoaded(mixed));
      await _settle(tester);
      verifyNever(
        () => h.backend.capture(AnalyticsEvents.tripParcelsViewed, any()),
      );
    });

    testWidgets('filtre : seules les lignes du statut, résumé inchangé, '
        'trip_parcels_filtered ; « Tous » revient', (tester) async {
      await open(tester, TripActivity.parcels, bids: mixed);
      final summaryBefore = tester
          .widget<Text>(find.byKey(const Key('trip-parcels-summary')))
          .textSpan!
          .toPlainText();
      await tester.tap(
        find.descendant(
          of: find.byType(StatusChipsRow<String?>),
          matching: find.textContaining('Accepté'),
        ),
      );
      await _settle(tester);
      expect(row('a1'), findsOneWidget);
      expect(row('a2'), findsOneWidget);
      expect(row('t1'), findsNothing);
      expect(row('d1'), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('trip-parcels-summary')))
            .textSpan!
            .toPlainText(),
        summaryBefore,
      );
      verify(
        () => h.backend.capture(AnalyticsEvents.tripParcelsFiltered, {
          'status': 'ACCEPTED',
        }),
      ).called(1);
      await tester.tap(find.text('Tous · 4'));
      await _settle(tester);
      expect(row('t1'), findsOneWidget);
      verify(
        () => h.backend.capture(AnalyticsEvents.tripParcelsFiltered, {
          'status': 'all',
        }),
      ).called(1);
    });

    testWidgets('statut filtré disparu de la liste relue : retour à « Tous »', (
      tester,
    ) async {
      await open(tester, TripActivity.parcels, bids: mixed);
      await tester.tap(
        find.descendant(
          of: find.byType(StatusChipsRow<String?>),
          matching: find.textContaining('En transit'),
        ),
      );
      await _settle(tester);
      expect(row('a1'), findsNothing);
      h.screenStates.add(
        BidListLoaded([
          for (final b in mixed)
            if (b.id != 't1') b,
        ]),
      );
      await _settle(tester);
      expect(row('a1'), findsOneWidget);
      expect(row('d1'), findsOneWidget);
    });

    testWidgets('un seul statut : pas de puces', (tester) async {
      await open(
        tester,
        TripActivity.parcels,
        bids: [
          answerBid('a1', status: 'ACCEPTED'),
          answerBid('a2', status: 'ACCEPTED'),
        ],
      );
      expect(find.byType(StatusChipsRow<String?>), findsNothing);
      expect(row('a1'), findsOneWidget);
    });

    testWidgets('aucun colis : état vide, bouton du pied gardé', (
      tester,
    ) async {
      await open(tester, TripActivity.parcels, bids: [answerBid('p1')]);
      expect(
        find.byKey(const Key('trip-activity-parcels-empty')),
        findsOneWidget,
      );
      expect(find.text('Aucun colis embarqué'), findsOneWidget);
      expect(
        find.byKey(const Key('trip-activity-parcels-open-list')),
        findsOneWidget,
      );
      verify(
        () =>
            h.backend.capture(AnalyticsEvents.tripParcelsViewed, {'count': 0}),
      ).called(1);
    });

    testWidgets('liste pas chargée : indicateur, mesure à l\'arrivée de la '
        'liste', (tester) async {
      await open(tester, TripActivity.parcels);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      verifyNever(
        () => h.backend.capture(AnalyticsEvents.tripParcelsViewed, any()),
      );
      h.screenStates.add(BidListLoaded(mixed));
      await _settle(tester);
      expect(row('a1'), findsOneWidget);
      verify(
        () =>
            h.backend.capture(AnalyticsEvents.tripParcelsViewed, {'count': 4}),
      ).called(1);
    });

    testWidgets('ligne : sheet fermé, fiche du colis, relecture au retour', (
      tester,
    ) async {
      final pushed = await open(tester, TripActivity.parcels, bids: mixed);
      await tester.tap(row('t1'));
      await _settle(tester);
      expect(pushed.single.location, '/bids/t1');
      await tester.tap(find.text('back'));
      await _settle(tester);
      expect(
        find.byKey(const Key('trip-activity-parcels-content')),
        findsNothing,
      );
      expect((h.screenEvents.single as BidListRequested).silent, isTrue);
    });

    testWidgets('« Ouvrir la liste des colis » : /announcements/:id/bids, '
        'relecture au retour, double appui ignoré', (tester) async {
      final pushed = await open(tester, TripActivity.parcels, bids: mixed);
      final button = find.byKey(const Key('trip-activity-parcels-open-list'));
      expect(find.descendant(of: footer(), matching: button), findsOneWidget);
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await _settle(tester);
      expect(pushed, hasLength(1));
      expect(pushed.single.location, '/announcements/trip-1/bids');
      expect(pushed.single.extra, {'title': 'Colis'});
      expect(h.screenEvents, isEmpty);
      await tester.tap(find.text('back'));
      await _settle(tester);
      expect((h.screenEvents.single as BidListRequested).silent, isTrue);
      expect(h.annEvents.single, isA<AnnouncementDetailRequested>());
    });

    testWidgets('trajet retiré par l\'équipe pendant l\'ouverture : le sheet '
        'se ferme seul', (tester) async {
      await open(tester, TripActivity.parcels, bids: mixed);
      h.annStates.add(
        AnnouncementDetailLoaded(answerTrip(status: 'REMOVED_BY_ADMIN')),
      );
      await _settle(tester);
      expect(
        find.byKey(const Key('trip-activity-parcels-content')),
        findsNothing,
      );
    });

    testWidgets('anglais', (tester) async {
      await open(
        tester,
        TripActivity.parcels,
        bids: mixed,
        locale: const Locale('en'),
      );
      expect(find.text('Parcels on this trip'), findsOneWidget);
      expect(find.text('All · 4'), findsOneWidget);
      expect(find.text('Open parcel list'), findsOneWidget);
    });
  });

  group('Gain', () {
    testWidgets('détail du gain, lecture seule, sans pied', (tester) async {
      await open(tester, TripActivity.gain, bids: const []);
      expect(find.text('Gain estimé'), findsOneWidget);
      expect(find.byKey(const Key('trip-summary-earnings')), findsOneWidget);
      expect(find.text('2 colis en votre possession'), findsOneWidget);
      expect(footer(), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('trip-activity-gain-content')),
          matching: find.byType(DonyButton),
        ),
        findsNothing,
      );
    });

    testWidgets('sans colis remis : ce qu\'il faut attendre', (tester) async {
      await open(tester, TripActivity.gain, trip: answerTrip(), bids: const []);
      expect(find.byKey(const Key('trip-activity-gain-empty')), findsOneWidget);
      expect(
        find.text('Le gain s\'affiche dès qu\'un colis vous est remis.'),
        findsOneWidget,
      );
    });

    testWidgets('gain nul (espèces) : « Résumé du trajet »', (tester) async {
      await open(
        tester,
        TripActivity.gain,
        trip: answerTrip(
          parcelsSummary: const TripParcelsSummary(
            count: 1,
            totalKg: 3,
            netAmount: 0,
            currency: 'EUR',
          ),
        ),
        bids: const [],
      );
      expect(find.text('Résumé du trajet'), findsOneWidget);
      expect(find.byKey(const Key('trip-summary-earnings')), findsNothing);
    });

    testWidgets('trajet annulé pendant l\'ouverture : le sheet se ferme seul', (
      tester,
    ) async {
      await open(tester, TripActivity.gain, bids: const []);
      h.annStates.add(
        AnnouncementDetailLoaded(
          answerTrip(status: 'CANCELLED', parcelsSummary: _summary),
        ),
      );
      await _settle(tester);
      expect(find.byKey(const Key('trip-activity-gain-content')), findsNothing);
    });
  });

  group('360 dp × 1,3, vraies polices', () {
    for (final (locale, label) in [
      (const Locale('fr'), 'Ouvrir la liste des colis'),
      (const Locale('en'), 'Open parcel list'),
    ]) {
      testWidgets('${locale.languageCode} : pied à taille nominale, sheets '
          'sans exception', (tester) async {
        await open(
          tester,
          TripActivity.parcels,
          bids: [
            for (var i = 0; i < 10; i++)
              answerBid(
                'p$i',
                status: i.isEven ? 'IN_TRANSIT' : 'ACCEPTED',
                description: 'Vêtements, chaussures et produits de beauté',
              ),
          ],
          locale: locale,
          textScale: 1.3,
          size: const Size(360, 800),
        );
        expect(tester.takeException(), isNull);
        final text = find.text(label);
        final fitted = find.ancestor(
          of: text,
          matching: find.byType(FittedBox),
        );
        expect(
          tester.getSize(fitted.first).width / tester.getSize(text).width,
          closeTo(1, 0.01),
        );
      });

      testWidgets('${locale.languageCode} : demandes, Refuser et Accepter à '
          'taille nominale', (tester) async {
        await open(
          tester,
          TripActivity.requests,
          bids: answerRequests(3),
          locale: locale,
          textScale: 1.3,
          size: const Size(360, 800),
        );
        expect(tester.takeException(), isNull);
        final text = find
            .descendant(
              of: find.byKey(const Key('trip-request-accept-r1')),
              matching: find.byType(Text),
            )
            .first;
        final fitted = find.ancestor(
          of: text,
          matching: find.byType(FittedBox),
        );
        expect(
          tester.getSize(fitted.first).width / tester.getSize(text).width,
          closeTo(1, 0.01),
        );
      });
    }
  });
}
