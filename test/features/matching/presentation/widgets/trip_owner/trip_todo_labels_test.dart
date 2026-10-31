// Textes et icônes des actions « À traiter » de l'écran du trajet
// (`trip_todo_labels.dart`) : libellés existants repris au mot près, textes
// des 16 types en FR et EN (pluriels, sans tiret cadratin), icônes
// présentes dans les assets, échéances (durée, heure, date, fuseau du
// trajet, délai dépassé) et bandeau des sheets par colis.
import 'dart:io';

import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'trip_todo_fixtures.dart';

TripTodoItem _item(
  TripTodoKind kind, {
  int count = 1,
  List<String> bidIds = const [],
  DateTime? dueAt,
  Map<String, DateTime> dueAtByBid = const {},
}) => TripTodoItem(
  kind: kind,
  count: count,
  bidIds: bidIds,
  dueAt: dueAt,
  dueAtByBid: dueAtByBid,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  final fr = lookupAppLocalizations(const Locale('fr'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('chaque situation des fixtures met son type en tête', () {
    for (final kind in TripTodoKind.values) {
      final todo = todoOf(todoScenarioFor(kind));
      expect(todo, isNotEmpty, reason: kind.name);
      expect(todo.first.kind, kind, reason: kind.name);
    }
  });

  group('libellés existants repris au mot près', () {
    for (final l in [fr, en]) {
      test(l.localeName, () {
        String button(TripTodoKind k, {int n = 1, bool ready = false}) =>
            tripTodoButton(l, _item(k, count: n), cardReady: ready);
        String title(TripTodoKind k, {bool ready = false}) =>
            tripTodoTitle(l, _item(k), cardReady: ready);
        expect(button(TripTodoKind.depart), l.tripDepartButton);
        expect(title(TripTodoKind.depart), l.tripDepartButton);
        expect(button(TripTodoKind.arrive), l.tripOwnerMarkArrivedButton);
        expect(title(TripTodoKind.arrive), l.tripOwnerMarkArrivedButton);
        expect(button(TripTodoKind.presence), l.bidDetailConfirmPresence);
        expect(button(TripTodoKind.scan), l.bidDetailScanParcelQr);
        expect(button(TripTodoKind.deliver), l.bidDetailConfirmHandover);
        expect(button(TripTodoKind.supplement), l.supplementCommissionConfirm);
        expect(button(TripTodoKind.publish), l.tripOwnerPublishTile);
        expect(
          title(TripTodoKind.senderAbsence),
          l.bidDetailTravelerReportNoShowButton,
        );
        expect(
          title(TripTodoKind.instructions),
          l.tripOwnerArrivalEditingTitle,
        );
        expect(title(TripTodoKind.requests), l.tripTodoRequestsTitle);
        expect(
          button(TripTodoKind.requests, n: 3),
          l.listingSeeRequestsButton(3),
        );
        // « Ajouter la carte » suit le compte de paiement.
        expect(
          button(TripTodoKind.addCard, ready: true),
          l.listingEnableCardOnTripButton,
        );
        expect(
          button(TripTodoKind.addCard),
          l.listingActivateCardPaymentsButton,
        );
        expect(
          tripTodoSubtitle(l, _item(TripTodoKind.addCard), cardReady: true),
          l.tripTodoCardReadySummary,
        );
        expect(
          tripTodoSubtitle(l, _item(TripTodoKind.addCard), cardReady: false),
          l.tripTodoCardActivateSummary,
        );
        expect(
          tripTodoSubtitle(l, _item(TripTodoKind.depart), cardReady: false),
          l.tripTodoDepartSummary,
        );
      });
    }

    test('« Prévenir » compte les destinataires, pas l\'action', () {
      final item = _item(TripTodoKind.notify, bidIds: const ['a', 'b']);
      expect(
        tripTodoButton(fr, item, cardReady: false),
        'Prévenir les destinataires (2)',
      );
      expect(
        tripTodoTitle(fr, item, cardReady: false),
        'Prévenir 2 destinataires',
      );
    });

    test('résumé des demandes au singulier et au pluriel', () {
      expect(
        tripTodoSubtitle(fr, _item(TripTodoKind.requests), cardReady: false),
        'Une demande attend votre réponse',
      );
      expect(
        tripTodoSubtitle(
          fr,
          _item(TripTodoKind.requests, count: 3),
          cardReady: false,
        ),
        '3 demandes attendent votre réponse',
      );
    });
  });

  group('16 types, FR et EN', () {
    for (final l in [fr, en]) {
      for (final kind in TripTodoKind.values) {
        for (final n in const [1, 3]) {
          test('${l.localeName} ${kind.name} × $n', () {
            final item = _item(
              kind,
              count: n,
              bidIds: [for (var i = 0; i < n; i++) 'b$i'],
            );
            for (final text in [
              tripTodoTitle(l, item, cardReady: false),
              tripTodoSubtitle(l, item, cardReady: false),
              tripTodoButton(l, item, cardReady: false),
            ]) {
              expect(text.trim(), isNotEmpty);
              expect(text, isNot(contains('—')), reason: 'tiret cadratin');
              expect(text, isNot(contains('{')), reason: 'ICU non résolu');
            }
          });
        }
      }
    }

    test('pluriels', () {
      expect(
        tripTodoTitle(fr, _item(TripTodoKind.scan), cardReady: false),
        'Récupérer 1 colis',
      );
      expect(
        tripTodoTitle(fr, _item(TripTodoKind.scan, count: 2), cardReady: false),
        'Récupérer 2 colis',
      );
      expect(
        tripTodoTitle(en, _item(TripTodoKind.scan, count: 2), cardReady: false),
        'Collect 2 parcels',
      );
      expect(
        tripTodoButton(
          fr,
          _item(TripTodoKind.rate, count: 2),
          cardReady: false,
        ),
        'Noter les expéditeurs',
      );
      expect(fr.tripTodoMoreRow(1), '+ 1 autre à traiter');
      expect(fr.tripTodoMoreRow(4), '+ 4 autres à traiter');
      expect(en.tripTodoMoreRow(4), '+ 4 more to do');
      expect(fr.tripTodoBadge(5), 'À traiter · 5');
      expect(fr.tripTodoBadgeSemantics(1), '1 chose à traiter');
      expect(fr.tripTodoBadgeSemantics(5), '5 choses à traiter');
      expect(fr.tripParcelsLineAwaiting(1), '1 attend votre geste');
      expect(fr.tripParcelsLineAwaiting(3), '3 attendent votre geste');
    });

    test('une icône par type, présente dans les assets', () {
      for (final kind in TripTodoKind.values) {
        final icon = tripTodoIcon(kind);
        expect(
          File('assets/icons/$icon.svg').existsSync(),
          isTrue,
          reason: '${kind.name} : $icon',
        );
      }
    });

    test('étiquettes d\'urgence', () {
      expect(tripTodoUrgencyLabel(fr, TripTodoUrgency.urgent), 'Urgent');
      expect(
        tripTodoUrgencyLabel(fr, TripTodoUrgency.important),
        'Prochaine action',
      );
      expect(tripTodoUrgencyLabel(en, TripTodoUrgency.important), 'Next step');
    });
  });

  group('échéance courte', () {
    // Trajet sans fuseau servi : heure de l'appareil (tests en UTC ou
    // local, même conversion des deux côtés).
    final trip = todoTrip();
    final now = kTodoNow;
    String? due(Duration d, [AppLocalizations? l]) =>
        tripTodoDueLabel(l ?? fr, now.add(d), now: now, trip: trip);

    test('sans échéance : rien', () {
      expect(tripTodoDueLabel(fr, null, now: now, trip: trip), isNull);
    });

    test('passée, ou à l\'instant : « Délai dépassé »', () {
      expect(due(Duration.zero), 'Délai dépassé');
      expect(due(const Duration(minutes: -5)), 'Délai dépassé');
      expect(due(Duration.zero, en), 'Deadline passed');
    });

    test('moins d\'une heure : en minutes (au moins 1)', () {
      expect(due(const Duration(minutes: 40)), 'Expire dans 40 min');
      expect(due(const Duration(seconds: 20)), 'Expire dans 1 min');
      expect(due(const Duration(minutes: 40), en), 'Expires in 40 min');
    });

    test('moins de six heures : en heures', () {
      expect(due(const Duration(hours: 5, minutes: 59)), 'Expire dans 5 h');
      expect(due(const Duration(hours: 1)), 'Expire dans 1 h');
    });

    test('même jour, plus tard : « Avant HH:mm »', () {
      final at = DateTime(2026, 11, 1, 19);
      final early = DateTime(2026, 11, 1, 8);
      expect(tripTodoDueLabel(fr, at, now: early, trip: trip), 'Avant 19:00');
    });

    test('un autre jour : date courte et heure', () {
      expect(due(const Duration(days: 1)), 'Avant le 2 nov. à 12:00');
      expect(
        tripTodoDueLabel(
          en,
          now.add(const Duration(days: 1)),
          now: now,
          trip: trip,
        ),
        'Before Nov 2 at 12:00\u202fPM',
      );
    });

    test('fuseau du trajet différent de l\'appareil : la ville est nommée', () {
      final dakar = todoTrip(timezone: 'Pacific/Kiritimati');
      final label = tripTodoDueLabel(
        fr,
        now.add(const Duration(days: 2)),
        now: now,
        trip: dakar,
      );
      expect(label, contains('heure de Paris'));
    });
  });

  group('bandeau du sheet par colis', () {
    final trip = todoTrip();
    final now = kTodoNow;
    // Colis payé par carte : à la date limite + 1 h, le voyageur est déclaré
    // absent (back `recordTravelerNoShow`).
    final card = todoBid(
      'card',
      'ACCEPTED',
      paymentMethod: BidPaymentMethod.stripe,
    );
    final mobile = todoBid(
      'mm',
      'ACCEPTED',
      paymentMethod: BidPaymentMethod.mobileMoney,
    );
    // Colis payé en espèces : il est annulé, sans fautif
    // (`expireUnconfirmedCashHandover`).
    final cash = todoBid('cash', 'ACCEPTED');
    TripTodoItem threatened(
      TripTodoKind kind,
      DateTime dueAt,
      List<BidModel> bids,
    ) => _item(
      kind,
      count: bids.length,
      bidIds: [for (final b in bids) b.id],
      dueAt: dueAt,
      dueAtByBid: {for (final b in bids) b.id: dueAt},
    );
    String? banner(
      TripTodoKind kind,
      DateTime? dueAt, {
      List<BidModel>? bids,
      AppLocalizations? l,
    }) {
      final parcels = bids ?? [card];
      return tripTodoDueBanner(
        l ?? fr,
        dueAt == null
            ? _item(kind, bidIds: [for (final b in parcels) b.id])
            : threatened(kind, dueAt, parcels),
        now: now,
        trip: trip,
        bids: parcels,
      );
    }

    test('échéance et conséquence', () {
      expect(
        banner(TripTodoKind.scan, DateTime(2026, 11, 1, 19)),
        'Avant 19:00, sinon vous êtes déclaré absent.',
      );
      expect(
        banner(TripTodoKind.senderAbsence, DateTime(2026, 11, 1, 13)),
        'Avant 13:00, sinon c\'est vous qui êtes déclaré absent.',
      );
      expect(
        banner(TripTodoKind.returnParcel, DateTime(2026, 11, 3, 12)),
        'Avant le 3 nov. à 12:00, sinon l\'équipe Yadony est alertée.',
      );
      for (final kind in const [
        TripTodoKind.presence,
        TripTodoKind.amendment,
        TripTodoKind.supplement,
      ]) {
        expect(
          banner(kind, DateTime(2026, 11, 1, 18)),
          startsWith('Avant 18:00, sinon '),
          reason: kind.name,
        );
      }
    });

    test('espèces : le colis est annulé, jamais « déclaré absent »', () {
      for (final kind in const [
        TripTodoKind.scan,
        TripTodoKind.senderAbsence,
      ]) {
        expect(
          banner(kind, DateTime(2026, 11, 1, 19), bids: [cash]),
          'Avant 19:00, sinon le colis est annulé.',
          reason: kind.name,
        );
        expect(
          banner(kind, DateTime(2026, 11, 1, 19), bids: [cash], l: en),
          'Before 7:00\u202fPM, otherwise the parcel is cancelled.',
          reason: kind.name,
        );
      }
    });

    test('carte et mobile money : déclaré absent', () {
      expect(
        banner(TripTodoKind.scan, DateTime(2026, 11, 1, 19), bids: [mobile]),
        'Avant 19:00, sinon vous êtes déclaré absent.',
      );
      expect(
        banner(
          TripTodoKind.scan,
          DateTime(2026, 11, 1, 19),
          bids: [card, mobile],
        ),
        'Avant 19:00, sinon vous êtes déclaré absent.',
      );
    });

    test('espèces et carte mêlés : les deux, et une conséquence par ligne', () {
      for (final kind in const [
        TripTodoKind.scan,
        TripTodoKind.senderAbsence,
      ]) {
        expect(
          banner(kind, DateTime(2026, 11, 1, 19), bids: [cash, card]),
          'Avant 19:00, sinon le colis est annulé ou vous êtes déclaré '
          'absent.',
          reason: kind.name,
        );
      }
      final item = threatened(TripTodoKind.scan, DateTime(2026, 11, 1, 19), [
        cash,
        card,
      ]);
      expect(
        tripTodoParcelConsequence(fr, item, cash, bids: [cash, card]),
        'Sinon le colis est annulé',
      );
      expect(
        tripTodoParcelConsequence(fr, item, card, bids: [cash, card]),
        'Sinon vous êtes déclaré absent',
      );
      expect(
        tripTodoParcelConsequence(en, item, cash, bids: [cash, card]),
        'Otherwise the parcel is cancelled',
      );
      // Un seul moyen de paiement : le bandeau suffit, rien sur la ligne.
      final cardOnly = threatened(
        TripTodoKind.scan,
        DateTime(2026, 11, 1, 19),
        [card],
      );
      expect(
        tripTodoParcelConsequence(fr, cardOnly, card, bids: [card]),
        isNull,
      );
    });

    test(
      'colis déjà déclaré absent (sans échéance) : ni bandeau ni menace',
      () {
        final declared = todoBid(
          'declared',
          'ACCEPTED',
          paymentMethod: BidPaymentMethod.stripe,
          cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        );
        final item = _item(TripTodoKind.scan, bidIds: const ['declared']);
        expect(
          tripTodoDueBanner(fr, item, now: now, trip: trip, bids: [declared]),
          isNull,
        );
        // Mêlé à un colis espèces menacé : le bandeau ne parle que de lui, et
        // la ligne du colis déclaré ne porte aucune conséquence.
        final mixed = TripTodoItem(
          kind: TripTodoKind.scan,
          count: 2,
          bidIds: const ['cash', 'declared'],
          dueAt: DateTime(2026, 11, 1, 19),
          dueAtByBid: {'cash': DateTime(2026, 11, 1, 19)},
        );
        expect(
          tripTodoDueBanner(
            fr,
            mixed,
            now: now,
            trip: trip,
            bids: [cash, declared],
          ),
          'Avant 19:00, sinon le colis est annulé.',
        );
        expect(
          tripTodoParcelConsequence(
            fr,
            mixed,
            declared,
            bids: [cash, declared],
          ),
          isNull,
        );
      },
    );

    test('délai dépassé', () {
      expect(
        banner(TripTodoKind.scan, now.subtract(const Duration(minutes: 1))),
        'Délai dépassé.',
      );
    });

    test('sans échéance, ou sans conséquence connue : rien', () {
      expect(banner(TripTodoKind.scan, null), isNull);
      for (final kind in const [
        TripTodoKind.deliver,
        TripTodoKind.recipientDeclined,
        TripTodoKind.rate,
      ]) {
        expect(banner(kind, DateTime(2026, 11, 1, 18)), isNull);
      }
    });

    test('anglais', () {
      expect(
        banner(TripTodoKind.scan, DateTime(2026, 11, 1, 19), l: en),
        'Before 7:00\u202fPM, otherwise you are marked as absent.',
      );
    });
  });
}
