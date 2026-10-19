import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/models/bid_negotiation_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/commission_grid_test_doubles.dart';

BidNegotiation _thread({
  String? commissionGridId,
  double? commissionRate,
  double? commissionOverrideRate,
  double? commissionVoucherFactor,
  String currency = 'EUR',
}) => BidNegotiation(
  bidId: 'bid1',
  announcementId: 'ann1',
  status: 'NEGOTIATING',
  role: 'TRAVELER',
  currency: currency,
  commissionGridId: commissionGridId,
  commissionRate: commissionRate,
  commissionOverrideRate: commissionOverrideRate,
  commissionVoucherFactor: commissionVoucherFactor,
);

void main() {
  setUp(CommissionGridStore.reset);
  tearDown(CommissionGridStore.reset);

  group('grossForNegotiationNet', () {
    test('fil à grille, taux spécial 4 % et bon ×0,5, net 50 € → 51,00 €', () {
      // Vecteur de la fixture : « Négociation de trajet, net vers brut ».
      useTestCommissionGrid();
      final thread = _thread(
        commissionGridId: kTestGridId,
        commissionRate: 0.12,
        commissionOverrideRate: 0.04,
        commissionVoucherFactor: 0.5,
      );
      expect(grossForNegotiationNet(thread, 50), 51.00);
    });

    test('fil à grille sans réduction, net 20 € → 21,40 €', () {
      useTestCommissionGrid();
      final thread = _thread(commissionGridId: kTestGridId);
      expect(grossForNegotiationNet(thread, 20), 21.40);
    });

    test('grille figée connue par id prioritaire sur la grille active', () {
      // Grille en vigueur à 10 % : si elle servait, 20 € coûterait 22,00 €.
      useTestCommissionGrid(
        CommissionGrid(
          id: 'grid-now',
          effectiveFrom: DateTime.utc(2026, 11),
          tiers: const [CommissionTier(fromEur: 0, rate: 0.10)],
          minimums: const {'EUR': 1.00},
        ),
      );
      CommissionGridStore.put(testGrid757());
      final thread = _thread(commissionGridId: kTestGridId);
      expect(grossForNegotiationNet(thread, 20), 21.40);
    });

    test('grille figée inconnue : repli sur la grille en vigueur', () {
      useTestCommissionGrid();
      final thread = _thread(commissionGridId: 'grid-inconnue');
      expect(grossForNegotiationNet(thread, 20), 21.40);
    });

    test('francs CFA : minimum de 650 F relevé puis bon ×0,5', () {
      useTestCommissionGrid();
      final thread = _thread(
        commissionGridId: kTestGridId,
        currency: 'XOF',
        commissionVoucherFactor: 0.5,
      );
      // 7 % de 5 000 F = 350 F, relevé au minimum 650 F, puis ×0,5 = 325 F.
      expect(grossForNegotiationNet(thread, 5000), 5325);
    });

    test('fil hérité au taux 0,12, net 35 € → 39,20 €', () {
      final thread = _thread(commissionRate: 0.12);
      expect(grossForNegotiationNet(thread, 35), 39.20);
    });

    test('fil hérité : la grille en vigueur ne s applique pas (Ruling A8)', () {
      useTestCommissionGrid();
      final thread = _thread(commissionRate: 0.12);
      expect(grossForNegotiationNet(thread, 35), 39.20);
    });
  });
}
