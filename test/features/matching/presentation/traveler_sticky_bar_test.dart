import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_sticky_bar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BidModel bidWith(String status) => BidModel(
        id: 'b1',
        announcementId: 'a1',
        senderId: 's1',
        status: status,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  group('TravelerStickyBar.hasAction', () {
    test('true pour PENDING (cash / Mobile Money) — décision', () {
      expect(TravelerStickyBar.hasAction(bidWith('PENDING')), isTrue);
    });

    // Régression du fix : un bid payé par carte (séquestré) doit aussi exposer
    // la barre Accepter/Refuser dans le détail, comme la carte de liste.
    test('true pour PAYMENT_ESCROWED (carte, séquestré) — décision', () {
      expect(TravelerStickyBar.hasAction(bidWith('PAYMENT_ESCROWED')), isTrue);
    });

    test('true pour REJECTED — supprimer', () {
      expect(TravelerStickyBar.hasAction(bidWith('REJECTED')), isTrue);
    });

    test('true pour ACCEPTED (présence à confirmer)', () {
      expect(TravelerStickyBar.hasAction(bidWith('ACCEPTED')), isTrue);
    });

    test('true pour HANDED_OVER — transit', () {
      expect(TravelerStickyBar.hasAction(bidWith('HANDED_OVER')), isTrue);
    });

    test('true pour IN_TRANSIT — remise', () {
      expect(TravelerStickyBar.hasAction(bidWith('IN_TRANSIT')), isTrue);
    });

    test('false pour COMPLETED', () {
      expect(TravelerStickyBar.hasAction(bidWith('COMPLETED')), isFalse);
    });

    test('false pour CANCELLED', () {
      expect(TravelerStickyBar.hasAction(bidWith('CANCELLED')), isFalse);
    });

    test('false pour AWAITING_PAYMENT', () {
      expect(TravelerStickyBar.hasAction(bidWith('AWAITING_PAYMENT')), isFalse);
    });
  });
}
