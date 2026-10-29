// Tuiles « À traiter » de la fiche colis (vue voyageur) : quelles demandes
// deviennent des tuiles, leur titre, leur résumé et leur mesure d'affichage.
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_request_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_todo_tiles.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

BidSupplement _supplement(
  BidSupplementStatus status, {
  String id = 'sup-1',
  double? commission = 2,
}) => BidSupplement(
  id: id,
  status: status,
  rail: 'CASH',
  netAmount: 15,
  commissionAmount: commission,
  grossAmount: 17,
);

BidModel _bid({BidSupplement? supplement, String status = 'ACCEPTED'}) =>
    BidModel(
      id: 'bid-001',
      announcementId: 'ann-001',
      senderId: 'sender-001',
      status: status,
      paymentMethod: BidPaymentMethod.cash,
      supplement: supplement,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('travelerTodoTilesFor', () {
    test('sans supplément → aucune tuile', () {
      expect(travelerTodoTilesFor(_bid()), isEmpty);
    });

    test('frais de service à valider → supplement', () {
      expect(
        travelerTodoTilesFor(
          _bid(supplement: _supplement(BidSupplementStatus.commissionPending)),
        ),
        [TravelerTodoTile.supplement],
      );
    });

    // Aucun cas oublié : chaque autre statut reste une carte d'information
    // (ou rien), jamais une tuile.
    for (final s in BidSupplementStatus.values) {
      if (s == BidSupplementStatus.commissionPending) continue;
      test('${s.name} → pas de tuile', () {
        expect(travelerTodoTilesFor(_bid(supplement: _supplement(s))), isEmpty);
      });
    }
  });

  group('titre et résumé', () {
    final bid = _bid(
      supplement: _supplement(BidSupplementStatus.commissionPending),
    );
    final fee = formatSupplementAmount(2, 'EUR');

    test('FR', () {
      expect(
        travelerTodoTitle(fr, TravelerTodoTile.supplement),
        'Supplément de prix',
      );
      expect(
        travelerTodoSummary(fr, bid, TravelerTodoTile.supplement),
        '$fee de frais à valider',
      );
    });

    test('EN', () {
      expect(
        travelerTodoTitle(en, TravelerTodoTile.supplement),
        'Extra charge',
      );
      expect(
        travelerTodoSummary(en, bid, TravelerTodoTile.supplement),
        '$fee fee to confirm',
      );
    });

    test('frais inconnus → phrase sans montant', () {
      final unknown = _bid(
        supplement: _supplement(
          BidSupplementStatus.commissionPending,
          commission: null,
        ),
      );
      expect(
        travelerTodoSummary(fr, unknown, TravelerTodoTile.supplement),
        'Frais de service à valider',
      );
      expect(
        travelerTodoSummary(en, unknown, TravelerTodoTile.supplement),
        'Service fee to confirm',
      );
    });
  });

  group('mesures', () {
    test('bid_detail_todo_tile_shown : tuile, rôle, statut du colis ; '
        'dédoublonnage par statut et demande', () {
      final shown = travelerTodoShown(
        TravelerTodoTile.supplement,
        _bid(supplement: _supplement(BidSupplementStatus.commissionPending)),
      );
      expect(shown.event, AnalyticsEvents.bidDetailTodoTileShown);
      expect(shown.properties, {
        'tile': 'supplement',
        'role': 'traveler',
        'status': 'ACCEPTED',
      });
      expect(shown.status, 'ACCEPTED|sup-1');

      final other = travelerTodoShown(
        TravelerTodoTile.supplement,
        _bid(
          supplement: _supplement(
            BidSupplementStatus.commissionPending,
            id: 'sup-2',
          ),
        ),
      );
      expect(other.status, isNot(shown.status));
    });

    test('bid_supplement_viewed : surface tile, statut de la demande', () {
      final viewed = travelerTodoViewed(
        TravelerTodoTile.supplement,
        _bid(supplement: _supplement(BidSupplementStatus.commissionPending)),
      );
      expect(viewed, isNotNull);
      expect(viewed!.event, AnalyticsEvents.bidSupplementViewed);
      expect(viewed.properties, {
        'role': 'traveler',
        'status': 'commissionPending',
        'surface': 'tile',
      });
      expect(viewed.status, 'sup-1|commissionPending');
    });

    test('sans supplément : pas de mesure de carte', () {
      expect(travelerTodoViewed(TravelerTodoTile.supplement, _bid()), isNull);
    });
  });
}
