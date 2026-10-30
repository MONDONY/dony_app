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
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
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
    // ACTIVE et FULL : toujours (PROD-1N). Parti : seulement s'il reste des
    // demandes (le back les expire au départ et refuse tout nouveau colis).
    // Terminé : jamais, le back y refuse toute acceptation (même règle que la
    // tuile « À traiter »). Brouillon, annulé, retiré, inconnu : jamais.
    const withoutRequests = {
      'DRAFT': false,
      'ACTIVE': true,
      'FULL': true,
      'IN_PROGRESS': false,
      'COMPLETED': false,
      'CANCELLED': false,
      'REMOVED_BY_ADMIN': false,
      'SOMETHING_NEW': false,
    };
    const withRequests = {
      'DRAFT': false,
      'ACTIVE': true,
      'FULL': true,
      'IN_PROGRESS': true,
      'COMPLETED': false,
      'CANCELLED': false,
      'REMOVED_BY_ADMIN': false,
      'SOMETHING_NEW': false,
    };
    for (final MapEntry(key: status, value: shown) in withoutRequests.entries) {
      test('$status sans demande : ${shown ? 'affichée' : 'absente'}', () {
        expect(
          TripRequestsCard.shownFor(tripFixture(status: status), const []),
          shown,
        );
      });
    }
    for (final MapEntry(key: status, value: shown) in withRequests.entries) {
      test('$status avec une demande : ${shown ? 'affichée' : 'absente'}', () {
        expect(
          TripRequestsCard.shownFor(tripFixture(status: status), [
            bidFixture('b1', 'PENDING'),
          ]),
          shown,
        );
      });
    }

    test('parti, liste pas chargée : le compte du modèle décide', () {
      expect(
        TripRequestsCard.shownFor(
          tripFixture(status: 'IN_PROGRESS', pendingBidCount: 1),
          null,
        ),
        isTrue,
      );
      expect(
        TripRequestsCard.shownFor(tripFixture(status: 'IN_PROGRESS'), null),
        isFalse,
      );
    });

    test('terminé : absente même avec des demandes restées en attente', () {
      final trip = tripFixture(status: 'COMPLETED', pendingBidCount: 2);
      expect(TripRequestsCard.shownFor(trip, null), isFalse);
      expect(
        TripRequestsCard.shownFor(trip, [
          bidFixture('b1', 'PENDING'),
          bidFixture('b2', 'PAYMENT_ESCROWED'),
        ]),
        isFalse,
      );
    });

    test('même source que la tuile « À traiter »', () {
      expect(tripRequestsPhaseFor('ACTIVE'), TripRequestsPhase.open);
      expect(tripRequestsPhaseFor('FULL'), TripRequestsPhase.full);
      expect(tripRequestsPhaseFor('IN_PROGRESS'), TripRequestsPhase.departed);
      expect(tripRequestsPhaseFor('COMPLETED'), TripRequestsPhase.ended);
      for (final status in const [
        'DRAFT',
        'CANCELLED',
        'REMOVED_BY_ADMIN',
        'SOMETHING_NEW',
      ]) {
        expect(tripRequestsPhaseFor(status), isNull, reason: status);
      }
    });
  });

  group('sous-ligne selon le statut', () {
    String? hint(WidgetTester tester) {
      final f = find.byKey(const Key('trip-requests-card-hint'));
      return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
    }

    // La carte de statut, juste au-dessus, dit déjà qu'un trajet complet ne
    // reçoit plus de demande : pas de sous-ligne qui le répète.
    testWidgets('complet : aucune sous-ligne, avec ou sans demande', (
      tester,
    ) async {
      await pumpTripCard(
        tester,
        TripRequestsCard(
          trip: tripFixture(status: 'FULL'),
          bids: const [],
        ),
      );
      expect(countText(tester), 'Aucune demande à traiter');
      expect(hint(tester), isNull);

      await pumpTripCard(
        tester,
        TripRequestsCard(
          trip: tripFixture(status: 'FULL'),
          bids: [bidFixture('b1', 'PENDING')],
        ),
      );
      expect(countText(tester), '1 demande à traiter');
      expect(hint(tester), isNull);
      // Jamais « Répondez pour remplir votre trajet » : il est plein.
      expect(find.text('Répondez pour remplir votre trajet.'), findsNothing);
    });

    testWidgets('parti : aucune promesse de demandes à venir', (tester) async {
      await pumpTripCard(
        tester,
        TripRequestsCard(
          trip: tripFixture(status: 'IN_PROGRESS'),
          bids: [bidFixture('b1', 'PENDING')],
        ),
      );
      expect(countText(tester), '1 demande à traiter');
      expect(hint(tester), 'Trajet parti : plus de nouvelle demande.');
      expect(
        find.text("Elles arrivent ici dès qu'un expéditeur propose un colis."),
        findsNothing,
      );
    });

    testWidgets('en anglais', (tester) async {
      Future<String?> render(String status) async {
        await pumpTripCard(
          tester,
          TripRequestsCard(
            trip: tripFixture(status: status),
            bids: [bidFixture('b1', 'PENDING')],
          ),
          locale: const Locale('en'),
        );
        return hint(tester);
      }

      expect(await render('FULL'), isNull);
      expect(await render('IN_PROGRESS'), 'Trip underway: no new requests.');
    });
  });

  group('compte inconnu', () {
    // Ouvert par une notification (sans la liste des trajets), liste des
    // colis en chargement ou en échec : un 0 ne prouve rien.
    testWidgets('jamais « Aucune demande à traiter »', (tester) async {
      await pumpTripCard(
        tester,
        TripRequestsCard(trip: tripFixture(), bids: null),
      );

      expect(countText(tester), 'Voir les demandes de ce trajet');
      expect(find.text('Aucune demande à traiter'), findsNothing);
      expect(
        find.text("Elles arrivent ici dès qu'un expéditeur propose un colis."),
        findsNothing,
      );
      expect(find.byKey(const Key('trip-requests-card-hint')), findsNothing);
      // Toujours tappable.
      final ink = tester.widget<InkWell>(
        find.descendant(of: card(), matching: find.byType(InkWell)),
      );
      expect(ink.onTap, isNotNull);
    });

    testWidgets('complet : ligne neutre, sans sous-ligne', (tester) async {
      await pumpTripCard(
        tester,
        TripRequestsCard(trip: tripFixture(status: 'FULL'), bids: null),
      );

      expect(countText(tester), 'Voir les demandes de ce trajet');
      expect(find.byKey(const Key('trip-requests-card-hint')), findsNothing);
    });

    testWidgets('en anglais', (tester) async {
      await pumpTripCard(
        tester,
        TripRequestsCard(trip: tripFixture(), bids: null),
        locale: const Locale('en'),
      );

      expect(countText(tester), "See this trip's requests");
      expect(find.text('No requests to review'), findsNothing);
    });

    test('connu dès que la liste a répondu ou que le modèle annonce un '
        'compte', () {
      expect(tripPendingRequestCountKnown(tripFixture(), null), isFalse);
      expect(tripPendingRequestCountKnown(tripFixture(), const []), isTrue);
      expect(
        tripPendingRequestCountKnown(tripFixture(pendingBidCount: 2), null),
        isTrue,
      );
    });
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

    testWidgets('double appui : une seule page ouverte', (tester) async {
      final pushed = await pumpTripCard(
        tester,
        TripRequestsCard(trip: tripFixture(), bids: const []),
        bids: bidBloc,
        announcement: annBloc,
      );

      await tester.tap(card());
      await tester.tap(card());
      await tester.pumpAndSettle();
      expect(pushed, hasLength(1));

      // Revenue, la carte rouvre la page.
      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();
      await tester.tap(card());
      await tester.pumpAndSettle();
      expect(pushed, hasLength(2));
    });

    testWidgets('relecture du trajet silencieuse', (tester) async {
      await pumpTripCard(
        tester,
        TripRequestsCard(trip: tripFixture(), bids: const []),
        bids: bidBloc,
        announcement: annBloc,
      );

      await tester.tap(card());
      await tester.pumpAndSettle();
      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();
      final annEvent =
          verify(() => annBloc.add(captureAny())).captured.single
              as AnnouncementDetailRequested;
      expect(annEvent.silent, isTrue);
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
