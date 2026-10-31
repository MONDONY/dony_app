// Compteurs « Activité du trajet » : règles de visibilité (statut du trajet
// × demandes × colis), valeurs et libellés (fonction pure tripActivityFor),
// rendu, pastille, tap, demandes traitées depuis l'écran, FR et EN à
// 360 dp × 1,3.
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_activity_row.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_direct_request_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_live.dart';
import 'package:dony/l10n/generated/app_localizations_en.dart';
import 'package:dony/l10n/generated/app_localizations_fr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_answer_harness.dart';
import 'trip_owner_harness.dart' show kTripStatuses;

final _fr = AppLocalizationsFr();
final _en = AppLocalizationsEn();

const _summary = TripParcelsSummary(
  count: 2,
  totalKg: 6,
  netAmount: 84,
  currency: 'EUR',
);

List<TripActivity> _kinds(List<TripActivityCell> cells) => [
  for (final c in cells) c.activity,
];

void main() {
  group('tripActivityFor : visibilité par statut', () {
    // Attendu par statut : sans demande ni colis, avec une demande, puis
    // avec des colis remis (résumé servi par le détail).
    const expected = {
      'DRAFT': ([], [], []),
      'ACTIVE': (
        [TripActivity.requests, TripActivity.parcels, TripActivity.gain],
        [TripActivity.requests, TripActivity.parcels, TripActivity.gain],
        [TripActivity.requests, TripActivity.parcels, TripActivity.gain],
      ),
      'FULL': (
        [TripActivity.requests, TripActivity.parcels, TripActivity.gain],
        [TripActivity.requests, TripActivity.parcels, TripActivity.gain],
        [TripActivity.requests, TripActivity.parcels, TripActivity.gain],
      ),
      // Parti : Demandes seulement s'il reste des demandes à traiter.
      'IN_PROGRESS': (
        [TripActivity.parcels, TripActivity.gain],
        [TripActivity.requests, TripActivity.parcels, TripActivity.gain],
        [TripActivity.parcels, TripActivity.gain],
      ),
      // Terminé : jamais Demandes (le back refuse toute acceptation).
      'COMPLETED': (
        [TripActivity.parcels, TripActivity.gain],
        [TripActivity.parcels, TripActivity.gain],
        [TripActivity.parcels, TripActivity.gain],
      ),
      // Annulé : rien sans colis ; ses colis remis suivent la procédure de
      // retour, Colis et Gain restent leur chemin. Jamais Demandes.
      'CANCELLED': ([], [], [TripActivity.parcels, TripActivity.gain]),
      'REMOVED_BY_ADMIN': ([], [], []),
      'SOMETHING_NEW': (
        [TripActivity.parcels, TripActivity.gain],
        [TripActivity.parcels, TripActivity.gain],
        [TripActivity.parcels, TripActivity.gain],
      ),
    };
    for (final status in kTripStatuses) {
      test(status, () {
        final (empty, withRequest, withParcels) = expected[status]!;
        expect(
          _kinds(
            tripActivityFor(
              trip: answerTrip(status: status),
              bids: const [],
              l: _fr,
            ),
          ),
          empty,
          reason: 'sans demande',
        );
        expect(
          _kinds(
            tripActivityFor(
              trip: answerTrip(status: status),
              bids: [answerBid('r1')],
              l: _fr,
            ),
          ),
          withRequest,
          reason: 'avec une demande',
        );
        expect(
          _kinds(
            tripActivityFor(
              trip: answerTrip(status: status, parcelsSummary: _summary),
              bids: [answerBid('a1', status: 'IN_TRANSIT')],
              l: _fr,
            ),
          ),
          withParcels,
          reason: 'avec des colis',
        );
      });
    }
  });

  group('tripActivityFor : trajet annulé', () {
    List<TripActivityCell> cancelled({
      List<BidModel>? bids,
      TripParcelsSummary? summary,
      int confirmed = 0,
    }) => tripActivityFor(
      trip: answerTrip(
        status: 'CANCELLED',
        parcelsSummary: summary,
        confirmedParcelCount: confirmed,
      ),
      bids: bids,
      l: _fr,
    );

    test('deux colis remis en retour : case Colis, sans Gain sans résumé', () {
      final cells = cancelled(
        bids: [
          answerBid('h1', status: 'HANDED_OVER'),
          answerBid('h2', status: 'HANDED_OVER'),
        ],
      );
      expect(_kinds(cells), [TripActivity.parcels]);
      expect(cells.single.value, '2');
      expect(cells.single.label, '2 en route');
    });

    test('résumé servi par le détail : Colis et Gain avec son montant', () {
      final cells = cancelled(
        bids: [answerBid('h1', status: 'HANDED_OVER')],
        summary: _summary,
      );
      expect(_kinds(cells), [TripActivity.parcels, TripActivity.gain]);
      expect(
        cells.last.value,
        CurrencyFormatter.format(84, SupportedCurrency.eur),
      );
    });

    test('liste pas chargée, colis comptés par le détail : Colis à « - »', () {
      final cells = cancelled(confirmed: 1);
      expect(_kinds(cells), [TripActivity.parcels]);
      expect(cells.single.value, kTripActivityUnknown);
    });

    test('sans colis, ou demandes seules : aucune case', () {
      expect(cancelled(bids: const []), isEmpty);
      expect(cancelled(bids: [answerBid('r1')]), isEmpty);
      expect(cancelled(), isEmpty);
      // Colis clôturés ou annulés automatiquement : comptés seulement s'ils
      // sont embarqués (isAcceptedTabBid), comme le sheet.
      expect(cancelled(bids: [answerBid('x', status: 'REJECTED')]), isEmpty);
    });
  });

  group('tripActivityFor : Demandes', () {
    test('nombre à traiter, pastille, « à traiter »', () {
      final cell = tripActivityFor(
        trip: answerTrip(),
        bids: [
          answerBid('r1'),
          answerBid('e1', status: 'PAYMENT_ESCROWED'),
          answerBid('x', status: 'REJECTED'),
        ],
        l: _fr,
      ).first;
      expect(cell.activity, TripActivity.requests);
      expect(cell.value, '2');
      expect(cell.label, 'à traiter');
      expect(cell.dot, isTrue);
    });

    test('aucune : « 0 demande », sans pastille', () {
      final cell = tripActivityFor(
        trip: answerTrip(),
        bids: const [],
        l: _fr,
      ).first;
      expect(cell.value, '0');
      expect(cell.label, 'demande');
      expect(cell.dot, isFalse);
    });

    test('liste pas chargée : repli pendingBidCount, sinon un trait', () {
      final known = tripActivityFor(
        trip: answerTrip(pendingBidCount: 3),
        bids: null,
        l: _fr,
      ).first;
      expect(known.value, '3');
      expect(known.dot, isTrue);
      final unknown = tripActivityFor(
        trip: answerTrip(),
        bids: null,
        l: _fr,
      ).first;
      expect(unknown.value, kTripActivityUnknown);
      expect(unknown.dot, isFalse);
    });

    test('demandes traitées depuis l\'écran : retirées du compte', () {
      final cells = tripActivityFor(
        trip: answerTrip(),
        bids: [answerBid('r1'), answerBid('r2')],
        l: _fr,
        answered: {'r1'},
      );
      expect(cells.first.value, '1');
      // Parti : la dernière traitée fait disparaître la case.
      final departed = tripActivityFor(
        trip: answerTrip(status: 'IN_PROGRESS'),
        bids: [answerBid('r1')],
        l: _fr,
        answered: {'r1'},
      );
      expect(_kinds(departed), [TripActivity.parcels, TripActivity.gain]);
    });

    test('demande acceptée depuis l\'écran et relue acceptée : comptée '
        'dans Colis (même source que le sheet)', () {
      final before = tripActivityFor(
        trip: answerTrip(),
        bids: [
          answerBid('a1', status: 'ACCEPTED'),
          answerBid('a2', status: 'ACCEPTED'),
          answerBid('r1'),
        ],
        l: _fr,
      );
      expect(before[1].value, '2');
      // Relecture pas revenue : r1 encore en attente, ôtée des demandes.
      final pending = tripActivityFor(
        trip: answerTrip(),
        bids: [
          answerBid('a1', status: 'ACCEPTED'),
          answerBid('a2', status: 'ACCEPTED'),
          answerBid('r1'),
        ],
        l: _fr,
        answered: {'r1'},
      );
      expect(pending.first.value, '0');
      expect(pending[1].value, '2');
      // Relecture revenue : r1 acceptée, 3 colis à récupérer.
      final relu = tripActivityFor(
        trip: answerTrip(),
        bids: [
          answerBid('a1', status: 'ACCEPTED'),
          answerBid('a2', status: 'ACCEPTED'),
          answerBid('r1', status: 'ACCEPTED'),
        ],
        l: _fr,
        answered: {'r1'},
      );
      expect(relu.first.value, '0');
      expect(relu[1].value, '3');
      expect(relu[1].label, '3 à récupérer');
    });

    test('anglais', () {
      final cells = tripActivityFor(
        trip: answerTrip(),
        bids: [answerBid('r1')],
        l: _en,
      );
      expect(cells.first.label, 'to review');
      expect(
        tripActivityFor(trip: answerTrip(), bids: const [], l: _en).first.label,
        'requests',
      );
    });
  });

  group('tripActivityFor : Colis', () {
    TripActivityCell parcels(List<BidModel>? bids, {bool en = false}) =>
        tripActivityFor(
          trip: answerTrip(status: 'IN_PROGRESS'),
          bids: bids,
          l: en ? _en : _fr,
        ).firstWhere((c) => c.activity == TripActivity.parcels);

    test('« N en route » prime', () {
      final c = parcels([
        answerBid('a', status: 'ACCEPTED'),
        answerBid('h', status: 'HANDED_OVER'),
        answerBid('t', status: 'IN_TRANSIT'),
        answerBid('d', status: 'COMPLETED'),
        answerBid('p'),
      ]);
      expect(c.value, '4');
      expect(c.label, '2 en route');
      expect(c.dot, isFalse);
    });

    test('sinon « N à récupérer »', () {
      final c = parcels([
        answerBid('a', status: 'ACCEPTED'),
        answerBid('b', status: 'ACCEPTED'),
        answerBid('w', status: 'AWAITING_PAYMENT'),
      ]);
      expect(c.value, '3');
      expect(c.label, '2 à récupérer');
    });

    test('sinon « colis » ; aucun colis : 0', () {
      expect(parcels([answerBid('d', status: 'COMPLETED')]).label, 'colis');
      final none = parcels(const []);
      expect(none.value, '0');
      expect(none.label, 'colis');
    });

    test('liste pas chargée : un trait', () {
      expect(parcels(null).value, kTripActivityUnknown);
    });

    test('anglais', () {
      expect(
        parcels([answerBid('t', status: 'IN_TRANSIT')], en: true).label,
        '1 in transit',
      );
      expect(
        parcels([answerBid('a', status: 'ACCEPTED')], en: true).label,
        '1 to pick up',
      );
      expect(
        parcels([answerBid('d', status: 'COMPLETED')], en: true).label,
        'parcel',
      );
    });
  });

  group('tripActivityFor : Gain', () {
    TripActivityCell gain(TripParcelsSummary? s, {String status = 'ACTIVE'}) =>
        tripActivityFor(
          trip: answerTrip(status: status, parcelsSummary: s),
          bids: const [],
          l: _fr,
        ).last;

    test('gain net servi par le détail, dans sa devise', () {
      final c = gain(_summary);
      expect(c.activity, TripActivity.gain);
      expect(
        c.value,
        CurrencyFormatter.format(
          84,
          SupportedCurrency.fromCodeOrDefault('EUR'),
        ),
      );
      expect(c.label, 'gain');
    });

    test('XOF', () {
      final c = gain(
        const TripParcelsSummary(
          count: 1,
          totalKg: 3,
          netAmount: 25000,
          currency: 'XOF',
        ),
      );
      expect(
        c.value,
        CurrencyFormatter.format(
          25000,
          SupportedCurrency.fromCodeOrDefault('XOF'),
        ),
      );
    });

    test('sans résumé, ou gain nul (espèces) : un trait', () {
      expect(gain(null).value, kTripActivityUnknown);
      expect(
        gain(
          const TripParcelsSummary(
            count: 1,
            totalKg: 3,
            netAmount: 0,
            currency: 'EUR',
          ),
        ).value,
        kTripActivityUnknown,
      );
    });
  });

  group('TripActivityRow', () {
    late AnswerHarness h;
    late List<TripActivity> opened;

    setUpAll(() async {
      AnswerHarness.registerFallbacks();
      await loadAppFonts();
    });

    setUp(() async {
      h = AnswerHarness();
      await h.setUp();
      opened = [];
    });

    tearDown(() => h.tearDown());

    Future<void> pumpRow(
      WidgetTester tester, {
      String status = 'ACTIVE',
      List<BidModel>? bids,
      Locale locale = const Locale('fr'),
      double textScale = 1,
      Size size = const Size(400, 1000),
      bool withCard = false,
    }) => h
        .pump(
          tester,
          trip: answerTrip(status: status, parcelsSummary: _summary),
          bids: bids,
          locale: locale,
          textScale: textScale,
          size: size,
          body: (context) => TripTodoLive(
            trip: answerTrip(status: status, parcelsSummary: _summary),
            blocs: TripTodoBlocs.of(context),
            builder: (context, live) => Column(
              children: [
                if (withCard)
                  TripDirectRequestCard(
                    trip: live.trip,
                    bids: live.bids,
                    views: TodoTileViewLog(),
                    onSeeAll: () {},
                  ),
                TripActivityRow(
                  trip: live.trip,
                  bids: live.bids,
                  onOpen: opened.add,
                ),
              ],
            ),
          ),
        )
        .then((_) {});

    String value(WidgetTester tester, TripActivity a) => tester
        .widget<Text>(find.byKey(Key('trip-activity-${a.name}-value')))
        .data!;

    testWidgets('trois cases, pastille sur Demandes, tap → onOpen', (
      tester,
    ) async {
      await pumpRow(
        tester,
        bids: [
          answerBid('r1'),
          answerBid('t', status: 'IN_TRANSIT'),
        ],
      );
      expect(find.byKey(const Key('trip-activity-row')), findsOneWidget);
      expect(value(tester, TripActivity.requests), '1');
      expect(value(tester, TripActivity.parcels), '1');
      expect(find.text('1 en route'), findsOneWidget);
      expect(find.text('à traiter'), findsOneWidget);
      expect(
        find.byKey(const Key('trip-activity-requests-dot')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('trip-activity-parcels-dot')), findsNothing);
      for (final a in TripActivity.values) {
        await tester.tap(find.byKey(Key('trip-activity-${a.name}')));
      }
      expect(opened, TripActivity.values);
    });

    testWidgets('lecteur d\'écran : nom de la case, valeur, libellé', (
      tester,
    ) async {
      await pumpRow(tester, bids: [answerBid('r1')]);
      expect(find.bySemanticsLabel('Demandes : 1 à traiter'), findsOneWidget);
      expect(find.bySemanticsLabel('Colis : 0 colis'), findsOneWidget);
    });

    testWidgets('sans pastille quand rien n\'attend', (tester) async {
      await pumpRow(tester, bids: const []);
      expect(find.byKey(const Key('trip-activity-requests-dot')), findsNothing);
      expect(find.text('demande'), findsOneWidget);
    });

    testWidgets('brouillon : rien', (tester) async {
      await pumpRow(tester, status: 'DRAFT', bids: const []);
      expect(find.byKey(const Key('trip-activity-row')), findsNothing);
    });

    testWidgets('liste relue : les compteurs suivent', (tester) async {
      await pumpRow(tester, bids: [answerBid('r1')]);
      h.screenStates.add(
        BidListLoaded([answerBid('r1'), answerBid('r2'), answerBid('r3')]),
      );
      await tester.pump();
      await tester.pump();
      expect(value(tester, TripActivity.requests), '3');
    });

    testWidgets('demande acceptée depuis la carte : le compteur baisse '
        'avant la liste relue', (tester) async {
      await pumpRow(
        tester,
        bids: [answerBid('r1'), answerBid('r2')],
        withCard: true,
      );
      expect(value(tester, TripActivity.requests), '2');
      await tester.tap(find.byKey(const Key('trip-request-accept-r1')));
      await tester.pump();
      await tester.pump();
      h.answerStates.add(BidAccepted(answerBid('r1', status: 'ACCEPTED')));
      await tester.pump();
      await tester.pump();
      expect(value(tester, TripActivity.requests), '1');
      expect(h.answerEvents.single, isA<BidAcceptRequested>());
      await tester.pump(const Duration(seconds: 5));
    });

    for (final locale in const [Locale('fr'), Locale('en')]) {
      testWidgets('${locale.languageCode} à 360 dp × 1,3 : aucune exception, '
          'trois cases de même largeur', (tester) async {
        await pumpRow(
          tester,
          bids: [
            for (var i = 0; i < 12; i++) answerBid('r$i'),
            for (var i = 0; i < 10; i++) answerBid('a$i', status: 'ACCEPTED'),
          ],
          locale: locale,
          textScale: 1.3,
          size: const Size(360, 1000),
        );
        expect(tester.takeException(), isNull);
        final w = tester
            .getSize(find.byKey(const Key('trip-activity-requests')))
            .width;
        expect(
          tester.getSize(find.byKey(const Key('trip-activity-gain'))).width,
          closeTo(w, 1),
        );
      });
    }
  });
}
