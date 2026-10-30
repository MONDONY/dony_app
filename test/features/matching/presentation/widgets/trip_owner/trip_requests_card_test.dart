// Carte « Demandes » de l'écran du trajet (vue du voyageur) : statuts où
// elle s'affiche, compte des demandes à traiter (0, 1, plusieurs, repli sur
// le modèle tant que la liste n'a pas répondu), ouverture des demandes du
// trajet et relecture au retour, FR / EN, 360 dp × 1,3.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_requests_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'trip_card_harness.dart';

void main() {
  setUpAll(() async {
    registerFallbackValue(AnnouncementDetailRequested('fallback'));
    registerFallbackValue(BidListRequested('fallback'));
    await loadAppFonts();
  });

  Finder card() => find.byKey(const Key('trip-requests-card'));
  String countText(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('trip-requests-card-count')))
      .data!;

  group('statuts', () {
    const expected = {
      'DRAFT': false,
      'ACTIVE': true,
      'FULL': true,
      'IN_PROGRESS': true,
      'COMPLETED': true,
      'CANCELLED': false,
      'REMOVED_BY_ADMIN': false,
      'SOMETHING_NEW': false,
    };
    for (final MapEntry(key: status, value: shown) in expected.entries) {
      test('$status : ${shown ? 'affichée' : 'absente'}', () {
        expect(TripRequestsCard.shownFor(status), shown);
      });
    }
  });

  group('compte des demandes à traiter', () {
    testWidgets('aucune : « Aucune demande à traiter », jamais grisée', (
      tester,
    ) async {
      await pumpTripCard(
        tester,
        TripRequestsCard(
          trip: tripFixture(),
          bids: [bidFixture('b1', 'ACCEPTED'), bidFixture('b2', 'REJECTED')],
        ),
      );

      expect(find.text('Demandes'), findsOneWidget);
      expect(countText(tester), 'Aucune demande à traiter');
      expect(
        find.text("Elles arrivent ici dès qu'un expéditeur propose un colis."),
        findsOneWidget,
      );
      // Toujours tappable (PROD-1N) : la carte a son encre.
      final ink = tester.widget<InkWell>(
        find.descendant(of: card(), matching: find.byType(InkWell)),
      );
      expect(ink.onTap, isNotNull);
    });

    testWidgets('une demande en attente', (tester) async {
      await pumpTripCard(
        tester,
        TripRequestsCard(
          trip: tripFixture(),
          bids: [bidFixture('b1', 'PENDING'), bidFixture('b2', 'ACCEPTED')],
        ),
      );

      expect(countText(tester), '1 demande à traiter');
      expect(find.text('Répondez pour remplir votre trajet.'), findsOneWidget);
    });

    testWidgets('plusieurs, paiement séquestré compris', (tester) async {
      await pumpTripCard(
        tester,
        TripRequestsCard(
          trip: tripFixture(),
          bids: [
            bidFixture('b1', 'PENDING'),
            bidFixture('b2', 'PAYMENT_ESCROWED'),
            bidFixture('b3', 'PENDING'),
            bidFixture('b4', 'CANCELLED'),
          ],
        ),
      );

      expect(countText(tester), '3 demandes à traiter');
    });

    testWidgets('liste pas encore chargée : compte du modèle', (tester) async {
      await pumpTripCard(
        tester,
        TripRequestsCard(trip: tripFixture(pendingBidCount: 2), bids: null),
      );

      expect(countText(tester), '2 demandes à traiter');
    });

    testWidgets('liste chargée : elle prime sur le compte du modèle', (
      tester,
    ) async {
      await pumpTripCard(
        tester,
        TripRequestsCard(
          trip: tripFixture(pendingBidCount: 4),
          bids: const <BidModel>[],
        ),
      );

      expect(countText(tester), 'Aucune demande à traiter');
    });

    testWidgets('en anglais : singulier, pluriel, aucune', (tester) async {
      Future<String> render(List<BidModel> bids) async {
        await pumpTripCard(
          tester,
          TripRequestsCard(trip: tripFixture(), bids: bids),
          locale: const Locale('en'),
        );
        return countText(tester);
      }

      expect(
        await render([bidFixture('b1', 'PENDING')]),
        '1 request to review',
      );
      expect(
        await render([
          bidFixture('b1', 'PENDING'),
          bidFixture('b2', 'PENDING'),
        ]),
        '2 requests to review',
      );
      expect(await render(const []), 'No requests to review');
      expect(find.text('Requests'), findsOneWidget);
      expect(
        find.text('They show up here as soon as a sender offers a parcel.'),
        findsOneWidget,
      );
    });
  });

  group('navigation', () {
    late MockBidBloc bidBloc;
    late MockAnnouncementBloc annBloc;

    setUp(() {
      bidBloc = MockBidBloc();
      annBloc = MockAnnouncementBloc();
      whenListen(
        bidBloc,
        const Stream<BidState>.empty(),
        initialState: BidListLoaded([bidFixture('b1', 'PENDING')]),
      );
      whenListen(
        annBloc,
        const Stream<AnnouncementState>.empty(),
        initialState: AnnouncementDetailLoaded(tripFixture()),
      );
    });

    testWidgets('tap : demandes à traiter du trajet, relues au retour', (
      tester,
    ) async {
      final pushed = await pumpTripCard(
        tester,
        TripRequestsCard(trip: tripFixture(), bids: const []),
        bids: bidBloc,
        announcement: annBloc,
      );

      await tester.tap(card());
      await tester.pumpAndSettle();
      expect(
        pushed.single.location,
        '/demandes?filter=aTraiter&announcement=trip-1',
      );
      verifyNever(() => bidBloc.add(any()));

      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();
      final bidEvent =
          verify(() => bidBloc.add(captureAny())).captured.single
              as BidListRequested;
      expect(bidEvent.announcementId, 'trip-1');
      expect(bidEvent.silent, isTrue);
      final annEvent =
          verify(() => annBloc.add(captureAny())).captured.single
              as AnnouncementDetailRequested;
      expect(annEvent.id, 'trip-1');
    });

    testWidgets('sans blocs à l\'écran : la navigation suffit', (tester) async {
      final pushed = await pumpTripCard(
        tester,
        TripRequestsCard(trip: tripFixture(), bids: const []),
      );

      await tester.tap(card());
      await tester.pumpAndSettle();
      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();
      expect(pushed, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  });

  group('360 dp, texte × 1,3', () {
    for (final locale in const [Locale('fr'), Locale('en')]) {
      for (final bids in [
        const <BidModel>[],
        [for (var i = 0; i < 12; i++) bidFixture('b$i', 'PENDING')],
      ]) {
        testWidgets('${locale.languageCode}, ${bids.length} demandes : aucun '
            'débordement', (tester) async {
          await pumpTripCard(
            tester,
            TripRequestsCard(trip: tripFixture(), bids: bids),
            locale: locale,
            textScale: 1.3,
            size: kTripCardSmallPhone,
          );

          expect(tester.takeException(), isNull);
          expect(card(), findsOneWidget);
        });
      }
    }
  });
}
