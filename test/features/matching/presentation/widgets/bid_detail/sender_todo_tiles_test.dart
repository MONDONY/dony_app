// Tuiles « À traiter » de la fiche colis (vue expéditeur) : quelles demandes
// deviennent des tuiles, leur titre, leur résumé et leur mesure d'affichage.
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_info.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_todo_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_request_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

TripRescheduleInfo _reschedule({bool pending = true, DateTime? deadline}) =>
    TripRescheduleInfo(
      id: 'r1',
      reason: 'FLIGHT_CANCELLED',
      previousDepartureDate: DateTime(2026, 10, 9),
      newDepartureDate: DateTime(2026, 10, 13),
      decisionPending: pending,
      decisionDeadline: deadline,
    );

BidAmendment _amendment({
  String id = 'am-1',
  BidAmendmentStatus status = BidAmendmentStatus.proposed,
  double addedWeightKg = 3,
  List<BidAmendmentItem> items = const [],
}) => BidAmendment(
  id: id,
  status: status,
  rail: BidAmendment.railCash,
  addedWeightKg: addedWeightKg,
  items: items,
  grossAmount: 26.8,
);

BidModel _bid({
  String status = 'IN_TRANSIT',
  String? trackingToken = 'tok-abc123',
  String? recipientAppStatus,
  DateTime? replacementRequestedAt,
  TripRescheduleInfo? reschedule,
  List<BidAmendment> amendments = const [],
}) => BidModel(
  amendments: amendments,
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: 'sender-001',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  trackingToken: trackingToken,
  recipientAppStatus: recipientAppStatus,
  recipientReplacementRequestedAt: replacementRequestedAt,
  reschedule: reschedule,
);

final _eur = formatSupplementAmount(26.8, 'EUR');

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  final fr = lookupAppLocalizations(const Locale('fr'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('senderTodoTilesFor', () {
    test('rien à traiter → aucune tuile', () {
      expect(senderTodoTilesFor(_bid()), isEmpty);
    });

    test('report en attente de réponse → reschedule', () {
      expect(senderTodoTilesFor(_bid(reschedule: _reschedule())), [
        SenderTodoTile.reschedule,
      ]);
    });

    test('report déjà décidé → pas de tuile (la carte informe)', () {
      expect(
        senderTodoTilesFor(_bid(reschedule: _reschedule(pending: false))),
        isEmpty,
      );
    });

    for (final status in ['ACCEPTED', 'HANDED_OVER', 'IN_TRANSIT', 'ARRIVED']) {
      test('destinataire en refus, $status → recipient', () {
        expect(
          senderTodoTilesFor(
            _bid(status: status, recipientAppStatus: 'DECLINED'),
          ),
          [SenderTodoTile.recipient],
        );
      });
    }

    for (final status in ['COMPLETED', 'DELIVERED', 'CANCELLED', 'PENDING']) {
      test('destinataire en refus, $status → pas de tuile', () {
        expect(
          senderTodoTilesFor(
            _bid(status: status, recipientAppStatus: 'DECLINED'),
          ),
          isEmpty,
        );
      });
    }

    test('destinataire confirmé → pas de tuile', () {
      expect(
        senderTodoTilesFor(_bid(recipientAppStatus: 'CONFIRMED')),
        isEmpty,
      );
    });

    // Modification : tuile tant que la demande est ouverte (l'expéditeur peut
    // l'annuler, la payer, ou attend la commission du voyageur).
    for (final status in [
      BidAmendmentStatus.authorizationPending,
      BidAmendmentStatus.proposed,
      BidAmendmentStatus.commissionPending,
      BidAmendmentStatus.paymentPending,
    ]) {
      test('modification ${status.name} → amendment', () {
        expect(
          senderTodoTilesFor(
            _bid(
              status: 'ACCEPTED',
              amendments: [_amendment(status: status)],
            ),
          ),
          [SenderTodoTile.amendment],
        );
      });
    }

    for (final status in [
      BidAmendmentStatus.declined,
      BidAmendmentStatus.expired,
      BidAmendmentStatus.cancelled,
      BidAmendmentStatus.accepted,
      BidAmendmentStatus.refunded,
    ]) {
      test('modification ${status.name} → pas de tuile (la carte informe)', () {
        expect(
          senderTodoTilesFor(
            _bid(
              status: 'ACCEPTED',
              amendments: [_amendment(status: status)],
            ),
          ),
          isEmpty,
        );
      });
    }

    test('modification, report et refus : dans l\'ordre des anciennes '
        'cartes', () {
      expect(
        senderTodoTilesFor(
          _bid(
            status: 'ACCEPTED',
            recipientAppStatus: 'DECLINED',
            reschedule: _reschedule(),
            amendments: [_amendment()],
          ),
        ),
        [
          SenderTodoTile.amendment,
          SenderTodoTile.reschedule,
          SenderTodoTile.recipient,
        ],
      );
    });

    test('report et refus ensemble : report puis destinataire', () {
      expect(
        senderTodoTilesFor(
          _bid(recipientAppStatus: 'DECLINED', reschedule: _reschedule()),
        ),
        [SenderTodoTile.reschedule, SenderTodoTile.recipient],
      );
    });
  });

  group('titres et résumés', () {
    test('titres repris des cartes, FR et EN', () {
      expect(
        senderTodoTitle(fr, SenderTodoTile.recipient),
        'Destinataire à remplacer',
      );
      expect(senderTodoTitle(fr, SenderTodoTile.reschedule), 'Trajet reporté');
      expect(
        senderTodoTitle(en, SenderTodoTile.recipient),
        'Recipient to replace',
      );
      expect(
        senderTodoTitle(en, SenderTodoTile.reschedule),
        'Trip rescheduled',
      );
      expect(
        senderTodoTitle(fr, SenderTodoTile.amendment),
        'Modification du colis',
      );
      expect(senderTodoTitle(en, SenderTodoTile.amendment), 'Parcel edit');
    });

    test('modification : kilos ajoutés et montant, FR et EN', () {
      final bid = _bid(amendments: [_amendment()]);
      expect(
        senderTodoSummary(fr, bid, SenderTodoTile.amendment),
        fr.senderTodoAmendmentSummary('3 kg', _eur),
      );
      expect(
        senderTodoSummary(fr, bid, SenderTodoTile.amendment),
        contains('3 kg'),
      );
      expect(
        senderTodoSummary(fr, bid, SenderTodoTile.amendment),
        contains(_eur),
      );
      expect(
        senderTodoSummary(en, bid, SenderTodoTile.amendment),
        en.senderTodoAmendmentSummary('3 kg', _eur),
      );
    });

    test('modification : poids décimal à la langue', () {
      final bid = _bid(amendments: [_amendment(addedWeightKg: 2.5)]);
      expect(
        senderTodoSummary(fr, bid, SenderTodoTile.amendment),
        startsWith(fr.senderTodoAmendmentSummary('2,5 kg', '')),
      );
      expect(
        senderTodoSummary(en, bid, SenderTodoTile.amendment),
        startsWith(en.senderTodoAmendmentSummary('2.5 kg', '')),
      );
    });

    test('modification sans kilos (articles seuls) : le montant seul', () {
      final bid = _bid(
        amendments: [
          _amendment(
            addedWeightKg: 0,
            items: const [
              BidAmendmentItem(
                label: 'Téléphone',
                quantity: 1,
                grossAmount: 26.8,
              ),
            ],
          ),
        ],
      );
      expect(
        senderTodoSummary(fr, bid, SenderTodoTile.amendment),
        fr.senderTodoAmendmentAmount(_eur),
      );
    });

    test('destinataire : refus, ou demande du voyageur', () {
      final declined = _bid(recipientAppStatus: 'DECLINED');
      expect(
        senderTodoSummary(fr, declined, SenderTodoTile.recipient),
        fr.senderTodoRecipientSummary,
      );
      expect(
        senderTodoSummary(
          fr,
          _bid(
            recipientAppStatus: 'DECLINED',
            replacementRequestedAt: DateTime.utc(2026, 10, 6, 8),
          ),
          SenderTodoTile.recipient,
        ),
        fr.senderTodoRecipientRequested,
      );
    });

    test('report : échéance courte à l\'heure de l\'appareil', () {
      final deadline = DateTime.utc(2026, 10, 12, 16);
      final bid = _bid(reschedule: _reschedule(deadline: deadline));
      final local = deadline.toLocal();
      final hm =
          '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';

      final summary = senderTodoSummary(fr, bid, SenderTodoTile.reschedule);
      expect(summary, startsWith('Répondre avant le '));
      expect(summary, contains('12 oct.'));
      expect(summary, contains(hm));
      expect(
        senderTodoSummary(en, bid, SenderTodoTile.reschedule),
        startsWith('Reply by '),
      );
    });

    test('report sans échéance : les deux choix', () {
      expect(
        senderTodoSummary(
          fr,
          _bid(reschedule: _reschedule()),
          SenderTodoTile.reschedule,
        ),
        fr.senderTodoRescheduleChoice,
      );
    });
  });

  group('mesure d\'affichage', () {
    test('événement de tuile affichée, statut du colis', () {
      for (final tile in SenderTodoTile.values) {
        final shown = senderTodoShown(
          tile,
          _bid(status: 'ARRIVED', recipientAppStatus: 'DECLINED'),
        );
        expect(shown.event, AnalyticsEvents.bidDetailTodoTileShown);
        expect(shown.properties, {
          'tile': tile.name,
          'role': 'sender',
          'status': 'ARRIVED',
        });
        expect(shown.status, 'ARRIVED');
      }
    });

    test('modification : bid_amendment_viewed en plus, surface tuile, '
        'dédoublonné par demande et statut', () {
      final bid = _bid(
        status: 'ACCEPTED',
        amendments: [_amendment(status: BidAmendmentStatus.paymentPending)],
      );
      final viewed = senderTodoViewed(SenderTodoTile.amendment, bid)!;
      expect(viewed.event, AnalyticsEvents.bidAmendmentViewed);
      expect(viewed.properties, {
        'role': 'sender',
        'status': 'PAYMENT_PENDING',
        'surface': 'tile',
      });
      expect(viewed.status, 'am-1|PAYMENT_PENDING');
    });

    test('report et destinataire : pas de mesure de carte en plus', () {
      final bid = _bid(
        recipientAppStatus: 'DECLINED',
        reschedule: _reschedule(),
      );
      expect(senderTodoViewed(SenderTodoTile.reschedule, bid), isNull);
      expect(senderTodoViewed(SenderTodoTile.recipient, bid), isNull);
    });

    test('event name', () {
      expect(
        AnalyticsEvents.bidDetailTodoTileShown,
        'bid_detail_todo_tile_shown',
      );
    });
  });
}
