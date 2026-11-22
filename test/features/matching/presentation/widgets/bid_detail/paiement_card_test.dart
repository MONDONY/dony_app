import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/paiement_card.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/models/payment_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

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

PaymentModel _payment(
  PaymentStatus status, {
  double? refundedAmount,
  String currency = 'EUR',
}) => PaymentModel(
  id: 'pay-1',
  bidId: 'bid-pc-1',
  amount: 200,
  commissionAmount: 18,
  currency: currency,
  status: status,
  refundedAmount: refundedAmount,
);

Widget _wrap(BidModel bid, {PaymentModel? payment, Locale? locale}) {
  final home = Scaffold(
    body: PaiementCard(bid: bid, existingPayment: payment),
  );
  return locale == null
      ? MaterialApp(home: home)
      : localizedApp(home, locale: locale);
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

  testWidgets('supplément payé : total avec supplément, jamais le net', (
    tester,
  ) async {
    final bid = BidModel(
      id: 'bid-pc-1',
      announcementId: 'ann-1',
      senderId: 'sender-1',
      status: 'ACCEPTED',
      totalAmountEur: 182,
      totalSenderAmountEur: 200,
      totalSenderAmountWithSupplementEur: 216.8,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(_wrap(bid));

    final expected = formatPriceIn(216.8, 'EUR');
    expect(
      find.text('$expected séquestré : libéré à la livraison'),
      findsOneWidget,
    );
  });
  group('PaiementCard — états réels du paiement', () {
    String amount(BidModel bid) =>
        formatPriceIn(bid.totalSenderAmountEur!, bid.currency);

    bool hasIcon(String name) => find
        .byWidgetPredicate((w) => w is DonyIcon && w.name == name)
        .evaluate()
        .isNotEmpty;

    for (final status in ['PENDING', 'ACCEPTED']) {
      testWidgets(
        'stripe + $status + paiement échoué → « Paiement échoué » en rouge, '
        'jamais « séquestré »',
        (tester) async {
          final bid = _bid(status: status);
          await tester.pumpWidget(
            _wrap(bid, payment: _payment(PaymentStatus.failed)),
          );

          final text = tester.widget<Text>(find.text('Paiement échoué'));
          final cs = Theme.of(
            tester.element(find.text('Paiement échoué')),
          ).colorScheme;
          expect(text.style?.color, cs.error);
          expect(hasIcon('circle-alert'), isTrue);
          expect(hasIcon('lock'), isFalse);
          expect(find.textContaining('séquestré'), findsNothing);
        },
      );
    }

    testWidgets('stripe + ACCEPTED + paiement en séquestre → « séquestré »', (
      tester,
    ) async {
      final bid = _bid();
      await tester.pumpWidget(
        _wrap(bid, payment: _payment(PaymentStatus.escrow)),
      );

      expect(
        find.text('${amount(bid)} séquestré : libéré à la livraison'),
        findsOneWidget,
      );
      expect(find.text('Paiement échoué'), findsNothing);
    });

    testWidgets('stripe + AWAITING_PAYMENT → « à régler » (icône verrou)', (
      tester,
    ) async {
      final bid = _bid(status: 'AWAITING_PAYMENT');
      await tester.pumpWidget(_wrap(bid));

      expect(find.text('${amount(bid)} à régler'), findsOneWidget);
      expect(find.textContaining('séquestré'), findsNothing);
      expect(hasIcon('lock'), isTrue);
    });

    testWidgets(
      'stripe + AWAITING_PAYMENT + paiement échoué → « Paiement échoué »',
      (tester) async {
        final bid = _bid(status: 'AWAITING_PAYMENT');
        await tester.pumpWidget(
          _wrap(bid, payment: _payment(PaymentStatus.failed)),
        );

        expect(find.text('Paiement échoué'), findsOneWidget);
        expect(find.textContaining('à régler'), findsNothing);
      },
    );

    testWidgets('mobile money + AWAITING_PAYMENT → « à régler » + badge', (
      tester,
    ) async {
      final bid = _bid(
        status: 'AWAITING_PAYMENT',
        paymentMethod: BidPaymentMethod.mobileMoney,
      );
      await tester.pumpWidget(_wrap(bid));

      expect(find.text('${amount(bid)} à régler'), findsOneWidget);
      expect(find.textContaining('gardé en sécurité'), findsNothing);
      final badge = tester.widget<DonyBadge>(find.byType(DonyBadge));
      expect(badge.label, 'MOBILE MONEY');
    });

    testWidgets('mobile money + ACCEPTED → texte sécurisé inchangé', (
      tester,
    ) async {
      final bid = _bid(paymentMethod: BidPaymentMethod.mobileMoney);
      await tester.pumpWidget(_wrap(bid));

      expect(find.textContaining('gardé en sécurité'), findsOneWidget);
      expect(find.textContaining('à régler'), findsNothing);
    });

    testWidgets('PARCEL_REFUSED → « remboursé » (pas « séquestré »)', (
      tester,
    ) async {
      final bid = _bid(status: 'PARCEL_REFUSED');
      await tester.pumpWidget(_wrap(bid));

      expect(find.text('${amount(bid)} remboursé'), findsOneWidget);
      expect(find.textContaining('séquestré'), findsNothing);
    });

    for (final status in ['CANCELLED', 'REJECTED', 'NO_SHOW', 'EXPIRED']) {
      testWidgets('$status avec un ancien paiement échoué → « remboursé »', (
        tester,
      ) async {
        final bid = _bid(status: status);
        await tester.pumpWidget(
          _wrap(bid, payment: _payment(PaymentStatus.failed)),
        );

        expect(find.text('${amount(bid)} remboursé'), findsOneWidget);
        expect(find.text('Paiement échoué'), findsNothing);
      });
    }

    testWidgets(
      'COMPLETED avec un ancien paiement échoué → « libéré » (le colis gagne)',
      (tester) async {
        final bid = _bid(status: 'COMPLETED');
        await tester.pumpWidget(
          _wrap(bid, payment: _payment(PaymentStatus.failed)),
        );

        expect(find.text('Paiement libéré ✓'), findsOneWidget);
        expect(find.text('Paiement échoué'), findsNothing);
      },
    );

    testWidgets('sans paiement lu : ACCEPTED garde « séquestré »', (
      tester,
    ) async {
      final bid = _bid();
      await tester.pumpWidget(_wrap(bid));

      expect(
        find.text('${amount(bid)} séquestré : libéré à la livraison'),
        findsOneWidget,
      );
    });

    testWidgets('espèces ignore le paiement transmis', (tester) async {
      final bid = _bid(paymentMethod: BidPaymentMethod.cash);
      await tester.pumpWidget(
        _wrap(bid, payment: _payment(PaymentStatus.failed)),
      );

      expect(find.text('Paiement échoué'), findsNothing);
      expect(find.textContaining('espèces'), findsOneWidget);
    });

    testWidgets('anglais : « Payment failed » et « to pay »', (tester) async {
      enableEnglish();
      final failed = _bid(status: 'PENDING');
      await tester.pumpWidget(
        _wrap(
          failed,
          payment: _payment(PaymentStatus.failed),
          locale: const Locale('en'),
        ),
      );
      expect(find.text('Payment failed'), findsOneWidget);

      final toPay = _bid(status: 'AWAITING_PAYMENT');
      await tester.pumpWidget(_wrap(toPay, locale: const Locale('en')));
      await tester.pump();
      expect(find.text('${amount(toPay)} to pay'), findsOneWidget);
    });
  });

  // G : montant réellement remboursé (`refundedAmount` du paiement, frais
  // d'annulation déduits). Absent (back antérieur, rien encore remboursé) :
  // la carte reste celle d'aujourd'hui, le total payé.
  group('PaiementCard — montant réellement remboursé', () {
    for (final status in ['CANCELLED', 'NO_SHOW', 'REJECTED', 'EXPIRED']) {
      testWidgets('$status + refundedAmount → ce montant, pas le total payé', (
        tester,
      ) async {
        final bid = _bid(status: status);
        await tester.pumpWidget(
          _wrap(
            bid,
            payment: _payment(PaymentStatus.refunded, refundedAmount: 140),
          ),
        );

        expect(
          find.text('${formatPriceIn(140, 'EUR')} remboursé'),
          findsOneWidget,
        );
        expect(
          find.text('${formatPriceIn(200, 'EUR')} remboursé'),
          findsNothing,
        );
      });

      testWidgets('$status sans refundedAmount → total payé (comme '
          'aujourd\'hui)', (tester) async {
        final bid = _bid(status: status);
        await tester.pumpWidget(
          _wrap(bid, payment: _payment(PaymentStatus.refunded)),
        );

        expect(
          find.text('${formatPriceIn(200, 'EUR')} remboursé'),
          findsOneWidget,
        );
      });
    }

    testWidgets('paiement non lu (null) → total payé', (tester) async {
      final bid = _bid(status: 'CANCELLED');
      await tester.pumpWidget(_wrap(bid));
      expect(
        find.text('${formatPriceIn(200, 'EUR')} remboursé'),
        findsOneWidget,
      );
    });

    testWidgets('devise du paiement (minuscules du back) : franc CFA sans '
        'décimales', (tester) async {
      final bid = _bid(status: 'CANCELLED', currency: 'XOF');
      await tester.pumpWidget(
        _wrap(
          bid,
          payment: _payment(
            PaymentStatus.refunded,
            refundedAmount: 45922,
            currency: 'xof',
          ),
        ),
      );
      expect(
        find.text('${formatPriceIn(45922, 'XOF')} remboursé'),
        findsOneWidget,
      );
    });

    testWidgets('colis en cours : refundedAmount ignoré', (tester) async {
      final bid = _bid();
      await tester.pumpWidget(
        _wrap(bid, payment: _payment(PaymentStatus.escrow, refundedAmount: 5)),
      );
      expect(find.textContaining('remboursé'), findsNothing);
      expect(
        find.text(
          '${formatPriceIn(200, 'EUR')} séquestré : libéré à la livraison',
        ),
        findsOneWidget,
      );
    });

    testWidgets('anglais : « {amount} refunded » avec le montant remboursé', (
      tester,
    ) async {
      enableEnglish();
      final bid = _bid(status: 'CANCELLED');
      await tester.pumpWidget(
        _wrap(
          bid,
          payment: _payment(PaymentStatus.refunded, refundedAmount: 140),
          locale: const Locale('en'),
        ),
      );
      await tester.pump();
      expect(
        find.text('${formatPriceIn(140, 'EUR')} refunded'),
        findsOneWidget,
      );
    });
  });

  // Mobile money annulé avec une retenue : le dépôt n'est pas rendu en entier.
  group('PaiementCard — mobile money annulé avec retenue', () {
    BidModel mm(String status) =>
        _bid(status: status, paymentMethod: BidPaymentMethod.mobileMoney);

    for (final status in ['CANCELLED', 'NO_SHOW', 'EXPIRED']) {
      testWidgets('$status + refundedAmount < total → montant rendu (FR)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            mm(status),
            payment: _payment(PaymentStatus.refunded, refundedAmount: 170),
            locale: const Locale('fr'),
          ),
        );
        expect(
          find.text('${formatPriceIn(170, 'EUR')} remboursé'),
          findsOneWidget,
        );
        expect(find.byType(DonyBadge), findsNothing);
        expect(find.textContaining('gardé en sécurité'), findsNothing);
      });
    }

    testWidgets('EN : « refunded »', (tester) async {
      await tester.pumpWidget(
        _wrap(
          mm('CANCELLED'),
          payment: _payment(PaymentStatus.refunded, refundedAmount: 170),
          locale: const Locale('en'),
        ),
      );
      expect(
        find.text('${formatPriceIn(170, 'EUR')} refunded'),
        findsOneWidget,
      );
    });

    testWidgets('devise du paiement respectée (XOF)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          mm('CANCELLED'),
          payment: _payment(
            PaymentStatus.refunded,
            refundedAmount: 100,
            currency: 'XOF',
          ),
        ),
      );
      expect(
        find.text('${formatPriceIn(100, 'XOF')} remboursé'),
        findsOneWidget,
      );
    });

    testWidgets('refundedAmount absent → affichage d\'avant', (tester) async {
      await tester.pumpWidget(
        _wrap(mm('CANCELLED'), payment: _payment(PaymentStatus.refunded)),
      );
      expect(find.textContaining('remboursé'), findsNothing);
      expect(find.byType(DonyBadge), findsOneWidget);
    });

    testWidgets('refundedAmount égal au total → affichage d\'avant', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          mm('CANCELLED'),
          payment: _payment(PaymentStatus.refunded, refundedAmount: 200),
        ),
      );
      expect(find.textContaining('remboursé'), findsNothing);
      expect(find.byType(DonyBadge), findsOneWidget);
    });

    testWidgets('autre statut (ACCEPTED) → inchangé même avec le champ', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          mm('ACCEPTED'),
          payment: _payment(PaymentStatus.escrow, refundedAmount: 170),
        ),
      );
      expect(find.textContaining('remboursé'), findsNothing);
      expect(find.byType(DonyBadge), findsOneWidget);
    });
  });
}
