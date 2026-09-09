import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/paiement_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid({
  String status = 'ACCEPTED',
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
  double? totalAmountEur = 182.0,
  double? totalSenderAmountEur = 200.0,
  String currency = 'EUR',
}) {
  return BidModel(
    id: 'bid-pc-1',
    announcementId: 'ann-1',
    senderId: 'sender-1',
    status: status,
    paymentMethod: paymentMethod,
    totalAmountEur: totalAmountEur,
    totalSenderAmountEur: totalSenderAmountEur,
    currency: currency,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

Widget _wrap(BidModel bid) {
  return MaterialApp(
    home: Scaffold(body: PaiementCard(bid: bid)),
  );
}

void main() {
  group('PaiementCard — branche selon le mode de paiement', () {
    testWidgets(
      'Stripe (séquestré) → icône verrou, texte séquestré, pas de badge',
      (tester) async {
        final bid = _bid();
        await tester.pumpWidget(_wrap(bid));

        expect(find.text('Paiement'), findsOneWidget);

        final expected = formatPriceIn(bid.totalSenderAmountEur!, bid.currency);
        expect(
          find.text('$expected séquestré : libéré à la livraison'),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'lock'),
          findsOneWidget,
        );
        expect(find.byType(DonyBadge), findsNothing);
      },
    );

    testWidgets('Espèces → icône billet, texte espèces, badge CASH', (
      tester,
    ) async {
      final bid = _bid(paymentMethod: BidPaymentMethod.cash);
      await tester.pumpWidget(_wrap(bid));

      final expected = formatPriceIn(bid.totalSenderAmountEur!, bid.currency);
      expect(
        find.text('À régler en espèces à la remise : $expected'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'banknote'),
        findsOneWidget,
      );
      final badge = tester.widget<DonyBadge>(find.byType(DonyBadge));
      expect(badge.label, 'CASH');
      expect(badge.type, DonyBadgeType.warning);
    });

    testWidgets(
      'Mobile money → icône smartphone, texte dédié, badge MOBILE MONEY',
      (tester) async {
        final bid = _bid(paymentMethod: BidPaymentMethod.mobileMoney);
        await tester.pumpWidget(_wrap(bid));

        final expected = formatPriceIn(bid.totalSenderAmountEur!, bid.currency);
        expect(
          find.text(
            "Paiement mobile money, gardé en sécurité par Yadony jusqu'à "
            'la livraison : $expected',
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is DonyIcon && w.name == 'smartphone',
          ),
          findsOneWidget,
        );
        final badge = tester.widget<DonyBadge>(find.byType(DonyBadge));
        expect(badge.label, 'MOBILE MONEY');
        expect(badge.type, DonyBadgeType.info);
      },
    );
  });
}
