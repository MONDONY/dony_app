// Tuiles « À traiter » de la fiche colis (vue expéditeur) : quelles demandes
// deviennent des tuiles, leur titre, leur résumé et leur mesure d'affichage.
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_info.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_todo_tiles.dart';
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

BidModel _bid({
  String status = 'IN_TRANSIT',
  String? trackingToken = 'tok-abc123',
  String? recipientAppStatus,
  DateTime? replacementRequestedAt,
  TripRescheduleInfo? reschedule,
}) => BidModel(
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

    test('event name', () {
      expect(
        AnalyticsEvents.bidDetailTodoTileShown,
        'bid_detail_todo_tile_shown',
      );
    });
  });
}
