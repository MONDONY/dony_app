// Ligne Colis de l'écran du trajet (choix « Une ligne colis » du 31/10) :
// visibilité par statut (tripParcelsLineShown), titre « N colis · gain »,
// sous-titre court (« 4 en route · 2 à récupérer », état vide), avatars (trois au plus, ceux
// qui attendent un geste d'abord, tripParcelsActionFirst), rendu (hauteur,
// une ligne, lecteur d'écran, tap), FR et EN à 360 dp × 1,3.
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_parcels_line.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcel_rows.dart'
    show tripParcelsActionFirst, tripParcelsCounts, tripParcelsSummarySegments;
import 'package:dony/l10n/generated/app_localizations_en.dart';
import 'package:dony/l10n/generated/app_localizations_fr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_answer_harness.dart' show answerBid, answerTrip;
import 'trip_card_harness.dart';
import 'trip_owner_harness.dart' show kTripStatuses;

final _fr = AppLocalizationsFr();
final _en = AppLocalizationsEn();

String _eur(double v) => CurrencyFormatter.format(v, SupportedCurrency.eur);

const _summary = TripParcelsSummary(
  count: 2,
  totalKg: 6,
  netAmount: 84,
  currency: 'EUR',
);

List<BidModel> _parcels(int n, {String status = 'ACCEPTED'}) => [
  for (var i = 0; i < n; i++) answerBid('c$i', status: status),
];

void main() {
  group('tripParcelsLineShown : visibilité par statut', () {
    // Attendu par statut : sans colis (liste vide), avec un colis embarqué,
    // liste pas chargée sans colis compté, liste pas chargée avec des colis
    // comptés par le détail.
    const expected = {
      'DRAFT': (false, false, false, false),
      'ACTIVE': (true, true, true, true),
      'FULL': (true, true, true, true),
      'IN_PROGRESS': (true, true, true, true),
      'COMPLETED': (false, true, false, true),
      'CANCELLED': (false, true, false, true),
      'REMOVED_BY_ADMIN': (false, false, false, false),
      // Statut inconnu de l'app : comme un trajet terminé.
      'SOMETHING_NEW': (false, true, false, true),
    };
    for (final status in kTripStatuses) {
      test(status, () {
        final (empty, withParcel, unknown, counted) = expected[status]!;
        expect(
          tripParcelsLineShown(answerTrip(status: status), const []),
          empty,
          reason: 'sans colis',
        );
        expect(
          tripParcelsLineShown(answerTrip(status: status), [
            answerBid('h', status: 'HANDED_OVER'),
          ]),
          withParcel,
          reason: 'avec un colis',
        );
        expect(
          tripParcelsLineShown(answerTrip(status: status), null),
          unknown,
          reason: 'liste pas chargée',
        );
        expect(
          tripParcelsLineShown(
            answerTrip(status: status, confirmedParcelCount: 1),
            null,
          ),
          counted,
          reason: 'liste pas chargée, colis comptés (confirmedParcelCount)',
        );
        expect(
          tripParcelsLineShown(
            answerTrip(status: status, parcelsSummary: _summary),
            null,
          ),
          counted,
          reason: 'liste pas chargée, colis comptés (parcelsSummary)',
        );
      });
    }

    test(
      'trajet annulé : demandes seules ou colis refusés ne comptent pas',
      () {
        final cancelled = answerTrip(status: 'CANCELLED');
        expect(tripParcelsLineShown(cancelled, [answerBid('r1')]), isFalse);
        expect(
          tripParcelsLineShown(cancelled, [answerBid('x', status: 'REJECTED')]),
          isFalse,
        );
        // Liste chargée : elle prime sur des compteurs du détail périmés.
        expect(
          tripParcelsLineShown(
            answerTrip(status: 'CANCELLED', confirmedParcelCount: 2),
            const [],
          ),
          isFalse,
        );
      },
    );
  });

  test('liste chargée vide + compteurs du détail : pas de ligne sur un '
      'trajet terminé, annulé ou inconnu (limite documentée)', () {
    for (final status in ['COMPLETED', 'CANCELLED', 'SOMETHING_NEW']) {
      expect(
        tripParcelsLineShown(
          answerTrip(
            status: status,
            confirmedParcelCount: 3,
            parcelsSummary: _summary,
          ),
          const [],
        ),
        isFalse,
        reason: status,
      );
      // Liste pas chargée : les compteurs du détail décident.
      expect(
        tripParcelsLineShown(
          answerTrip(
            status: status,
            confirmedParcelCount: 3,
            parcelsSummary: _summary,
          ),
          null,
        ),
        isTrue,
        reason: status,
      );
    }
  });

  group('tripParcelsLineFor : titre', () {
    TripParcelsLineContent line(
      List<BidModel>? bids, {
      String status = 'ACTIVE',
      TripParcelsSummary? summary,
    }) => tripParcelsLineFor(
      trip: answerTrip(status: status, parcelsSummary: summary),
      bids: bids,
      l: _fr,
    )!;

    test('0, 1, 2, 10 colis', () {
      expect(line(const []).title, 'Aucun colis');
      expect(line(const []).count, 0);
      expect(line(_parcels(1)).title, '1 colis');
      expect(line(_parcels(2)).title, '2 colis');
      expect(line(_parcels(10)).title, '10 colis');
      expect(line(_parcels(10)).count, 10);
    });

    test('demandes en attente : jamais comptées comme colis', () {
      expect(line([answerBid('r1'), ..._parcels(1)]).title, '1 colis');
    });

    test('gain positif : « · gain estimé » au titre', () {
      expect(
        line([
          answerBid('t', status: 'IN_TRANSIT', net: 30),
          answerBid(
            'e',
            status: 'HANDED_OVER',
            method: BidPaymentMethod.cash,
            net: 20,
            gross: 22,
          ),
          answerBid('a', status: 'ACCEPTED', net: 50),
        ]).title,
        '3 colis · ${_eur(50)}',
      );
    });

    test('gain absent : pas de montant (colis acceptés seulement, aucun '
        'colis, résumé à 0)', () {
      expect(
        line([answerBid('a', status: 'ACCEPTED', net: 50)]).title,
        '1 colis',
      );
      expect(line(const []).title, 'Aucun colis');
      expect(
        line(
          const [],
          summary: const TripParcelsSummary(
            count: 0,
            totalKg: 0,
            netAmount: 0,
            currency: 'EUR',
          ),
        ).title,
        'Aucun colis',
      );
    });

    test(
      'liste vide : jamais de gain au titre, même si le détail en sert un',
      () {
        const net = TripParcelsSummary(
          count: 2,
          totalKg: 6,
          netAmount: 42,
          currency: 'EUR',
        );
        for (final status in ['ACTIVE', 'FULL', 'IN_PROGRESS']) {
          expect(
            line(const [], status: status, summary: net).title,
            'Aucun colis',
          );
        }
        // Liste pas chargée : le gain du détail reste affiché.
        expect(line(null, summary: net).title, 'Colis · ${_eur(42)}');
        // Dès qu'un colis est dans la liste, le gain revient.
        expect(
          line([answerBid('t', status: 'IN_TRANSIT', net: 42)]).title,
          '1 colis · ${_eur(42)}',
        );
      },
    );

    test('liste pas chargée : « Colis », gain servi par le détail', () {
      final content = line(null, summary: _summary);
      expect(content.count, isNull);
      expect(content.title, 'Colis · ${_eur(84)}');
      expect(content.subtitle, isNull);
      expect(content.faces, isEmpty);
      expect(line(null).title, 'Colis');
    });

    test('XOF : devise du trajet', () {
      final content = tripParcelsLineFor(
        trip: answerTrip(currency: 'XOF'),
        bids: [
          answerBid('t', status: 'IN_TRANSIT', net: 15000, currency: 'XOF'),
        ],
        l: _fr,
      )!;
      expect(
        content.title,
        '1 colis · ${CurrencyFormatter.format(15000, SupportedCurrency.xof)}',
      );
    });

    test('anglais', () {
      String en(List<BidModel>? bids) =>
          tripParcelsLineFor(trip: answerTrip(), bids: bids, l: _en)!.title;
      expect(en(const []), 'No parcels');
      expect(en(_parcels(1)), '1 parcel');
      expect(en(_parcels(10)), '10 parcels');
      expect(en(null), 'Parcels');
    });
  });

  group('tripParcelsLineFor : sous-titre', () {
    String? subtitle(List<BidModel> bids) =>
        tripParcelsLineFor(trip: answerTrip(), bids: bids, l: _fr)!.subtitle;

    test('aucun colis : « Les colis acceptés apparaîtront ici. »', () {
      expect(subtitle(const []), 'Les colis acceptés apparaîtront ici.');
    });

    test('segments non vides, dans l\'ordre du cycle', () {
      expect(
        subtitle([
          for (var i = 0; i < 2; i++) answerBid('d$i', status: 'COMPLETED'),
          answerBid('ar', status: 'ARRIVED'),
          for (var i = 0; i < 2; i++) answerBid('a$i', status: 'ACCEPTED'),
          for (var i = 0; i < 3; i++) answerBid('t$i', status: 'IN_TRANSIT'),
          answerBid('h', status: 'HANDED_OVER'),
        ]),
        '4 en route · 2 à récupérer · 1 arrivé · 2 livrés',
      );
      expect(subtitle(_parcels(2)), '2 à récupérer');
    });

    test('mêmes comptes que le résumé du sheet Colis, sans « colis »', () {
      final bids = [
        answerBid('t', status: 'IN_TRANSIT'),
        answerBid('d', status: 'COMPLETED'),
      ];
      final counts = tripParcelsCounts(bids);
      final summary = tripParcelsSummarySegments(_fr, counts);
      final short = tripParcelsLineSegments(_fr, counts);
      expect(short.map((s) => s.$1), summary.map((s) => s.$1));
      expect(short.map((s) => s.$2), ['en route', 'livré']);
      expect(summary.first.$2, 'colis en route');
      expect(subtitle(bids), '1 en route · 1 livré');
    });

    test('singulier et pluriel : arrivé(s), livré(s)', () {
      expect(
        subtitle([
          answerBid('ar', status: 'ARRIVED'),
          answerBid('d', status: 'COMPLETED'),
        ]),
        '1 arrivé · 1 livré',
      );
      expect(
        subtitle([
          for (var i = 0; i < 2; i++) answerBid('ar$i', status: 'ARRIVED'),
          for (var i = 0; i < 3; i++) answerBid('d$i', status: 'COMPLETED'),
        ]),
        '2 arrivés · 3 livrés',
      );
    });

    test('jamais le mot « colis » au sous-titre', () {
      for (final bids in [
        [answerBid('t', status: 'IN_TRANSIT')],
        [
          answerBid('a', status: 'ACCEPTED'),
          answerBid('d', status: 'COMPLETED'),
        ],
      ]) {
        expect(subtitle(bids), isNot(contains('colis')));
      }
    });

    test('colis sans segment (paiement attendu, absence) : pas de '
        'sous-titre', () {
      expect(subtitle([answerBid('w', status: 'AWAITING_PAYMENT')]), isNull);
      expect(subtitle([answerBid('n', status: 'NO_SHOW')]), isNull);
    });

    test('anglais', () {
      String? en(List<BidModel> bids) =>
          tripParcelsLineFor(trip: answerTrip(), bids: bids, l: _en)!.subtitle;
      expect(en(const []), 'Accepted parcels will appear here.');
      expect(
        en([
          answerBid('t', status: 'IN_TRANSIT'),
          answerBid('a', status: 'ACCEPTED'),
        ]),
        '1 in transit · 1 to pick up',
      );
      expect(
        en([
          for (var i = 0; i < 2; i++) answerBid('ar$i', status: 'ARRIVED'),
          answerBid('d', status: 'COMPLETED'),
        ]),
        '2 arrived · 1 delivered',
      );
    });
  });

  group('tripParcelsLineFor : avatars', () {
    List<String> faces(List<BidModel> bids) => [
      for (final b in tripParcelsLineFor(
        trip: answerTrip(),
        bids: bids,
        l: _fr,
      )!.faces)
        b.id,
    ];

    test('aucun colis : aucun avatar (icône)', () {
      expect(faces(const []), isEmpty);
    });

    test('1, 2 colis : un avatar par colis', () {
      expect(faces(_parcels(1)), ['c0']);
      expect(faces(_parcels(2)), ['c0', 'c1']);
    });

    test('10 colis : trois avatars au plus', () {
      expect(faces(_parcels(10)), ['c0', 'c1', 'c2']);
    });

    test('ceux qui attendent un geste d\'abord, ordre reçu gardé', () {
      expect(
        faces([
          answerBid('d1', status: 'COMPLETED'),
          answerBid('w', status: 'AWAITING_PAYMENT'),
          answerBid('a1', status: 'ACCEPTED'),
          answerBid('d2', status: 'COMPLETED'),
          answerBid('ar', status: 'ARRIVED'),
          answerBid('t', status: 'IN_TRANSIT'),
        ]),
        ['a1', 'ar', 't'],
      );
      expect(
        faces([
          answerBid('d1', status: 'COMPLETED'),
          answerBid('a1', status: 'ACCEPTED'),
        ]),
        ['a1', 'd1'],
      );
    });

    test('tripParcelsActionFirst : tous gardés, les autres ensuite', () {
      expect(
        [
          for (final b in tripParcelsActionFirst([
            answerBid('d', status: 'COMPLETED'),
            answerBid('h', status: 'HANDED_OVER'),
            answerBid('n', status: 'NO_SHOW'),
            answerBid('a', status: 'ACCEPTED'),
          ]))
            b.id,
        ],
        ['h', 'a', 'd', 'n'],
      );
    });
  });

  group('TripParcelsLine', () {
    late int opened;

    setUpAll(loadAppFonts);
    setUp(() => opened = 0);

    Future<void> pumpLine(
      WidgetTester tester, {
      String status = 'ACTIVE',
      List<BidModel>? bids = const [],
      TripParcelsSummary? summary,
      Locale locale = const Locale('fr'),
      double textScale = 1,
      Size size = const Size(400, 800),
    }) => pumpTripCard(
      tester,
      TripParcelsLine(
        trip: answerTrip(status: status, parcelsSummary: summary),
        bids: bids,
        onOpen: () => opened++,
      ),
      locale: locale,
      textScale: textScale,
      size: size,
    ).then((_) {});

    final line = find.byKey(const Key('trip-parcels-line'));

    testWidgets('aucun colis : icône, « Aucun colis », état vide', (
      tester,
    ) async {
      await pumpLine(tester);
      expect(find.byKey(const Key('trip-parcels-line-icon')), findsOneWidget);
      expect(find.byKey(const Key('trip-parcels-line-faces')), findsNothing);
      expect(find.text('Aucun colis'), findsOneWidget);
      expect(find.text('Les colis acceptés apparaîtront ici.'), findsOneWidget);
    });

    testWidgets('colis : avatars à la place de l\'icône, titre et résumé', (
      tester,
    ) async {
      await pumpLine(
        tester,
        bids: [
          answerBid('t', status: 'IN_TRANSIT', net: 30),
          answerBid('a', status: 'ACCEPTED'),
        ],
      );
      expect(find.byKey(const Key('trip-parcels-line-icon')), findsNothing);
      expect(find.byKey(const Key('trip-parcels-line-face-t')), findsOneWidget);
      expect(find.byKey(const Key('trip-parcels-line-face-a')), findsOneWidget);
      expect(find.text('2 colis · ${_eur(30)}'), findsOneWidget);
      expect(find.text('1 en route · 1 à récupérer'), findsOneWidget);
    });

    testWidgets('dix colis : trois avatars', (tester) async {
      await pumpLine(tester, bids: _parcels(10));
      expect(
        find.descendant(
          of: find.byKey(const Key('trip-parcels-line-faces')),
          matching: find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  'trip-parcels-line-face-',
                ),
          ),
        ),
        findsNWidgets(3),
      );
      expect(find.text('10 colis'), findsOneWidget);
    });

    testWidgets('une seule ligne de 56 à 64 px, texte sur une ligne', (
      tester,
    ) async {
      await pumpLine(tester, bids: _parcels(2));
      final height = tester.getSize(line).height;
      expect(height, inInclusiveRange(56, 64));
      for (final key in const [
        'trip-parcels-line-title',
        'trip-parcels-line-subtitle',
      ]) {
        final text = tester.widget<Text>(find.byKey(Key(key)));
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
      }
    });

    testWidgets('tap : onOpen', (tester) async {
      await pumpLine(tester, bids: _parcels(1));
      await tester.tap(line);
      expect(opened, 1);
    });

    testWidgets('lecteur d\'écran : titre puis résumé, un bouton', (
      tester,
    ) async {
      await pumpLine(tester, bids: _parcels(2));
      expect(find.bySemanticsLabel('2 colis. 2 à récupérer'), findsOneWidget);
    });

    for (final status in const ['DRAFT', 'REMOVED_BY_ADMIN']) {
      testWidgets('$status : rien', (tester) async {
        await pumpLine(tester, status: status, bids: _parcels(2));
        expect(line, findsNothing);
      });
    }

    testWidgets('trajet terminé sans colis : rien ; avec colis : la ligne', (
      tester,
    ) async {
      await pumpLine(tester, status: 'COMPLETED');
      expect(line, findsNothing);
      await pumpLine(
        tester,
        status: 'COMPLETED',
        bids: [answerBid('d', status: 'COMPLETED', net: 10)],
      );
      expect(find.text('1 colis · ${_eur(10)}'), findsOneWidget);
      expect(find.text('1 livré'), findsOneWidget);
    });

    testWidgets('trajet annulé avec colis remis : la ligne reste', (
      tester,
    ) async {
      await pumpLine(
        tester,
        status: 'CANCELLED',
        bids: [
          answerBid('h1', status: 'HANDED_OVER'),
          answerBid('h2', status: 'HANDED_OVER'),
        ],
      );
      expect(find.text('2 colis'), findsOneWidget);
      expect(find.text('2 en route'), findsOneWidget);
    });

    testWidgets('liste pas chargée : « Colis », icône, sans sous-titre', (
      tester,
    ) async {
      await pumpLine(tester, bids: null, summary: _summary);
      expect(find.text('Colis · ${_eur(84)}'), findsOneWidget);
      expect(find.byKey(const Key('trip-parcels-line-icon')), findsOneWidget);
      expect(find.byKey(const Key('trip-parcels-line-subtitle')), findsNothing);
    });

    testWidgets('anglais', (tester) async {
      await pumpLine(
        tester,
        bids: [answerBid('t', status: 'IN_TRANSIT', net: 30)],
        locale: const Locale('en'),
      );
      expect(find.text('1 parcel · ${_eur(30)}'), findsOneWidget);
      expect(find.text('1 in transit'), findsOneWidget);
    });

    for (final locale in const [Locale('fr'), Locale('en')]) {
      testWidgets('${locale.languageCode} à 360 dp × 1,3 : aucune exception, '
          'titre et résumé sur une ligne', (tester) async {
        await pumpLine(
          tester,
          bids: [
            for (var i = 0; i < 4; i++)
              answerBid('t$i', status: 'IN_TRANSIT', net: 1234.5),
            for (var i = 0; i < 2; i++) answerBid('a$i', status: 'ACCEPTED'),
            answerBid('ar', status: 'ARRIVED'),
            for (var i = 0; i < 2; i++)
              answerBid('d$i', status: 'COMPLETED', net: 999),
          ],
          locale: locale,
          textScale: 1.3,
          size: const Size(360, 800),
        );
        expect(tester.takeException(), isNull);
        for (final key in const [
          'trip-parcels-line-title',
          'trip-parcels-line-subtitle',
        ]) {
          expect(tester.widget<Text>(find.byKey(Key(key))).maxLines, 1);
        }
        // La ligne reste dans l'écran.
        expect(tester.getSize(line).width, lessThanOrEqualTo(360));
      });
    }
  });
}
