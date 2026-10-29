import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_money_breakdown.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/money_breakdown_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid({
  required String status,
  double? total = 48,
  double? senderTotal,
  BidPaymentMethod method = BidPaymentMethod.stripe,
  String currency = 'EUR',
  double? netWithSupplement,
  BidMoneyBreakdown? breakdown,
}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: status,
  weightKg: 5,
  totalAmountEur: total,
  totalSenderAmountEur: senderTotal,
  totalNetAmountWithSupplementEur: netWithSupplement,
  paymentMethod: method,
  currency: currency,
  moneyBreakdown: breakdown,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

Future<void> _pump(WidgetTester tester, BidModel bid) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: TravelerGainCard(bid: bid)),
  ),
);

void main() {
  test('travelerAmountLabel formate le net dans la devise du bid', () {
    expect(travelerAmountLabel(_bid(status: 'ACCEPTED')), contains('48'));
    expect(travelerAmountLabel(_bid(status: 'ACCEPTED')), contains('€'));
    expect(travelerAmountLabel(_bid(status: 'ACCEPTED', total: null)), '-');
  });

  testWidgets('Stripe actif → "Vous recevez" + séquestré', (tester) async {
    await _pump(tester, _bid(status: 'ACCEPTED'));
    expect(find.text('VOUS RECEVEZ'), findsOneWidget);
    expect(find.textContaining('48'), findsOneWidget);
    expect(find.textContaining('séquestré'), findsOneWidget);
  });

  testWidgets('Stripe COMPLETED → "Vous avez reçu" + Reçu', (tester) async {
    await _pump(tester, _bid(status: 'COMPLETED'));
    expect(find.text('VOUS AVEZ REÇU'), findsOneWidget);
    expect(find.textContaining('Reçu'), findsOneWidget);
  });

  testWidgets('Stripe annulé → paiement annulé', (tester) async {
    await _pump(tester, _bid(status: 'CANCELLED'));
    expect(find.textContaining('annulé'), findsOneWidget);
  });

  testWidgets('Cash sans brut (ancien back) → net + note historique', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(status: 'ACCEPTED', method: BidPaymentMethod.cash),
    );
    expect(find.text('VOUS ENCAISSEZ'), findsOneWidget);
    expect(find.text('${formatPriceIn(48, 'EUR')} en espèces'), findsOneWidget);
    expect(
      find.text(
        'Frais de service avancés sur votre solde Yadony, remboursés par '
        'l\'expéditeur dans ce montant.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('pour vous'), findsNothing);
  });

  // FLUTTER-R8 : en espèces, l'expéditeur remet le BRUT au voyageur ; la
  // commission est prélevée à part. Afficher le net laissait croire que
  // l'expéditeur payait moins que ce qu'il remet réellement.
  testWidgets('Cash avec brut → brut encaissé + détail commission et net', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(
        status: 'ACCEPTED',
        method: BidPaymentMethod.cash,
        senderTotal: 50.4,
      ),
    );
    expect(
      find.text('${formatPriceIn(50.4, 'EUR')} en espèces'),
      findsOneWidget,
    );
    expect(
      find.text(
        '${formatPriceIn(48, 'EUR')} pour vous + ${formatPriceIn(2.4, 'EUR')} '
        'de frais de service, avancés sur votre solde Yadony et remboursés '
        'par l\'expéditeur dans ce montant.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Frais de service avancés sur votre solde Yadony, remboursés par '
        'l\'expéditeur dans ce montant.',
      ),
      findsNothing,
    );
  });

  testWidgets('Cash avec brut en XOF → montants dans la devise du colis', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(
        status: 'ACCEPTED',
        method: BidPaymentMethod.cash,
        total: 20000,
        senderTotal: 21000,
        currency: 'XOF',
      ),
    );
    expect(
      find.text('${formatPriceIn(21000, 'XOF')} en espèces'),
      findsOneWidget,
    );
    expect(
      find.textContaining('${formatPriceIn(20000, 'XOF')} pour vous'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '+ ${formatPriceIn(1000, 'XOF')} de frais de service, avancés',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Cash avec brut égal au net → pas de ligne de détail', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(status: 'ACCEPTED', method: BidPaymentMethod.cash, senderTotal: 48),
    );
    expect(find.text('${formatPriceIn(48, 'EUR')} en espèces'), findsOneWidget);
    expect(find.textContaining('pour vous'), findsNothing);
    expect(
      find.text(
        'Frais de service avancés sur votre solde Yadony, remboursés par '
        'l\'expéditeur dans ce montant.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Stripe avec brut → toujours le net, sans détail espèces', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'ACCEPTED', senderTotal: 50.4));
    expect(find.text(formatPriceIn(48, 'EUR')), findsOneWidget);
    expect(find.textContaining('pour vous'), findsNothing);
    expect(find.textContaining('espèces'), findsNothing);
  });

  test('travelerCashGrossAmount : brut sinon repli sur le net', () {
    expect(
      travelerCashGrossAmount(_bid(status: 'ACCEPTED', senderTotal: 50)),
      50,
    );
    expect(travelerCashGrossAmount(_bid(status: 'ACCEPTED')), 48);
  });

  // Un paiement mobile money était présenté comme un encaissement en espèces.
  testWidgets(
    'Mobile money actif → "Vous recevez" + mobile money, jamais espèces',
    (tester) async {
      await _pump(
        tester,
        _bid(status: 'ACCEPTED', method: BidPaymentMethod.mobileMoney),
      );
      expect(find.text('VOUS RECEVEZ'), findsOneWidget);
      expect(find.textContaining('mobile money'), findsWidgets);
      expect(find.textContaining('espèces'), findsNothing);
      expect(find.text('VOUS ENCAISSEZ'), findsNothing);
    },
  );

  testWidgets('Mobile money COMPLETED → "Vous avez reçu" + Versé', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(status: 'COMPLETED', method: BidPaymentMethod.mobileMoney),
    );
    expect(find.text('VOUS AVEZ REÇU'), findsOneWidget);
    expect(find.textContaining('Versé'), findsWidgets);
    expect(find.textContaining('espèces'), findsNothing);
  });

  group('supplément payé', () {
    BidModel withSupplement({
      BidPaymentMethod method = BidPaymentMethod.stripe,
    }) => BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'ACCEPTED',
      totalAmountEur: 48,
      totalSenderAmountEur: 54,
      totalNetAmountWithSupplementEur: 63,
      totalSenderAmountWithSupplementEur: 70.8,
      paymentMethod: method,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );

    test('net et brut comptent le supplément', () {
      expect(travelerNetAmount(withSupplement()), 63);
      expect(travelerCashGrossAmount(withSupplement()), 70.8);
      expect(travelerAmountLabel(withSupplement()), formatPriceIn(63, 'EUR'));
    });

    testWidgets('carte : gain affiché avec le supplément', (tester) async {
      await _pump(tester, withSupplement());
      expect(find.text(formatPriceIn(63, 'EUR')), findsOneWidget);
    });
  });

  group('PARCEL_REFUSED', () {
    testWidgets(
      'Stripe → « PAIEMENT » / « Paiement annulé. », sans séquestre',
      (tester) async {
        await _pump(tester, _bid(status: 'PARCEL_REFUSED'));
        expect(find.text('PAIEMENT'), findsOneWidget);
        expect(find.text('Paiement annulé.'), findsOneWidget);
        expect(find.text('VOUS RECEVEZ'), findsNothing);
        expect(find.textContaining('séquestré'), findsNothing);
        expect(find.text('Libéré à la livraison.'), findsNothing);
      },
    );

    testWidgets('mobile money → « PAIEMENT », jamais le virement en attente', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(status: 'PARCEL_REFUSED', method: BidPaymentMethod.mobileMoney),
      );
      expect(find.text('PAIEMENT'), findsOneWidget);
      expect(find.text('Paiement annulé.'), findsOneWidget);
      expect(find.textContaining('mobile money'), findsNothing);
      expect(find.text('VOUS RECEVEZ'), findsNothing);
    });
  });

  // Matrice complète statut du colis × moyen de paiement. Le rendu attendu est
  // écrit en dur (pas recalculé) pour que tout changement de la carte casse un
  // test lisible.
  group('matrice statut × moyen de paiement', () {
    const allStatuses = [
      'PENDING',
      'PAYMENT_ESCROWED',
      'AWAITING_PAYMENT',
      'ACCEPTED',
      'HANDED_OVER',
      'IN_TRANSIT',
      'ARRIVED',
      'COMPLETED',
      'DELIVERED',
      'REJECTED',
      'CANCELLED',
      'NO_SHOW',
      'EXPIRED',
      'PARCEL_REFUSED',
    ];
    const inProgress = [
      'PENDING',
      'PAYMENT_ESCROWED',
      'AWAITING_PAYMENT',
      'ACCEPTED',
      'HANDED_OVER',
      'IN_TRANSIT',
      'ARRIVED',
    ];
    const done = ['COMPLETED', 'DELIVERED'];
    const notCompleted = [
      'REJECTED',
      'CANCELLED',
      'NO_SHOW',
      'EXPIRED',
      'PARCEL_REFUSED',
    ];

    test('la matrice couvre les 14 statuts une fois chacun', () {
      expect(
        [...inProgress, ...done, ...notCompleted]..sort(),
        [...allStatuses]..sort(),
      );
    });

    // Moyens servis par la carte « séquestre » : carte, Wave, Orange Money.
    for (final method in [
      BidPaymentMethod.stripe,
      BidPaymentMethod.wave,
      BidPaymentMethod.orangeMoney,
    ]) {
      for (final status in inProgress) {
        testWidgets('${method.name} · $status → séquestré', (tester) async {
          await _pump(tester, _bid(status: status, method: method));
          expect(find.text('VOUS RECEVEZ'), findsOneWidget);
          expect(find.text('Libéré à la livraison.'), findsOneWidget);
          expect(find.text('🔒 séquestré'), findsOneWidget);
          expect(find.text('PAIEMENT'), findsNothing);
        });
      }
      for (final status in done) {
        testWidgets('${method.name} · $status → reçu', (tester) async {
          await _pump(tester, _bid(status: status, method: method));
          expect(find.text('VOUS AVEZ REÇU'), findsOneWidget);
          expect(find.text('● Reçu'), findsOneWidget);
          expect(find.text('🔒 séquestré'), findsNothing);
        });
      }
      for (final status in notCompleted) {
        testWidgets('${method.name} · $status → paiement annulé', (
          tester,
        ) async {
          await _pump(tester, _bid(status: status, method: method));
          expect(find.text('PAIEMENT'), findsOneWidget);
          expect(find.text('Paiement annulé.'), findsOneWidget);
          expect(find.text('VOUS RECEVEZ'), findsNothing);
          expect(find.text('🔒 séquestré'), findsNothing);
        });
      }
    }

    for (final status in inProgress) {
      testWidgets('mobile money · $status → virement attendu', (tester) async {
        await _pump(
          tester,
          _bid(status: status, method: BidPaymentMethod.mobileMoney),
        );
        expect(find.text('VOUS RECEVEZ'), findsOneWidget);
        expect(
          find.text('Versé sur votre compte mobile money à la livraison.'),
          findsOneWidget,
        );
        expect(find.text('📱 mobile money'), findsOneWidget);
        expect(find.text('VOUS ENCAISSEZ'), findsNothing);
      });
    }
    for (final status in done) {
      testWidgets('mobile money · $status → versé', (tester) async {
        await _pump(
          tester,
          _bid(status: status, method: BidPaymentMethod.mobileMoney),
        );
        expect(find.text('VOUS AVEZ REÇU'), findsOneWidget);
        expect(
          find.text('Versé sur votre compte mobile money.'),
          findsOneWidget,
        );
        expect(find.text('● Versé'), findsOneWidget);
      });
    }
    for (final status in notCompleted) {
      testWidgets('mobile money · $status → paiement annulé', (tester) async {
        await _pump(
          tester,
          _bid(status: status, method: BidPaymentMethod.mobileMoney),
        );
        expect(find.text('PAIEMENT'), findsOneWidget);
        expect(find.text('Paiement annulé.'), findsOneWidget);
        expect(find.text('📱 mobile money'), findsNothing);
        expect(find.text('● Versé'), findsNothing);
      });
    }

    // Espèces : le moyen prime sur le statut (comportement historique, la
    // commission est prélevée à part quel que soit l'état du colis).
    for (final status in allStatuses) {
      testWidgets('espèces · $status → « VOUS ENCAISSEZ »', (tester) async {
        await _pump(
          tester,
          _bid(
            status: status,
            method: BidPaymentMethod.cash,
            senderTotal: 50.4,
          ),
        );
        expect(find.text('VOUS ENCAISSEZ'), findsOneWidget);
        expect(find.text('ESPÈCES'), findsOneWidget);
        expect(
          find.text('${formatPriceIn(50.4, 'EUR')} en espèces'),
          findsOneWidget,
        );
        expect(find.text('PAIEMENT'), findsNothing);
        expect(find.text('🔒 séquestré'), findsNothing);
      });
    }
  });

  group('colis modifié (moneyBreakdown) → MoneyBreakdownCard', () {
    const breakdown = BidMoneyBreakdown(
      lines: [
        MoneyLine(
          kind: MoneyLineKind.principal,
          refId: 'r1',
          method: 'STRIPE',
          amount: 54,
          status: 'SECURED',
        ),
      ],
      total: 54,
      onlineAmount: 54,
      cashAmount: 0,
    );

    for (final status in [
      'ACCEPTED',
      'IN_TRANSIT',
      'COMPLETED',
      'CANCELLED',
      'PARCEL_REFUSED',
    ]) {
      for (final method in BidPaymentMethod.values) {
        testWidgets('$status · ${method.name}', (tester) async {
          await _pump(
            tester,
            _bid(status: status, method: method, breakdown: breakdown),
          );
          expect(find.byType(MoneyBreakdownCard), findsOneWidget);
          expect(find.text('VOUS ENCAISSEZ'), findsNothing);
          expect(find.text('PAIEMENT'), findsNothing);
        });
      }
    }
  });

  group('supplément net et devise XOF', () {
    testWidgets(
      'PARCEL_REFUSED : le montant affiché est le net avec supplément',
      (tester) async {
        await _pump(
          tester,
          _bid(status: 'PARCEL_REFUSED', netWithSupplement: 63),
        );
        expect(find.text('PAIEMENT'), findsOneWidget);
        expect(find.text(formatPriceIn(63, 'EUR')), findsOneWidget);
      },
    );

    testWidgets('séquestre avec supplément payé → net avec supplément', (
      tester,
    ) async {
      await _pump(tester, _bid(status: 'ACCEPTED', netWithSupplement: 63));
      expect(find.text(formatPriceIn(63, 'EUR')), findsOneWidget);
    });

    testWidgets(
      'reçu avec supplément payé (mobile money) → net avec supplément',
      (tester) async {
        await _pump(
          tester,
          _bid(
            status: 'COMPLETED',
            method: BidPaymentMethod.mobileMoney,
            netWithSupplement: 63,
          ),
        );
        expect(find.text(formatPriceIn(63, 'EUR')), findsOneWidget);
      },
    );

    testWidgets(
      'espèces avec supplément : brut distinct, net avec supplément',
      (tester) async {
        await _pump(
          tester,
          BidModel(
            id: 'b1',
            announcementId: 'a1',
            senderId: 's1',
            status: 'ACCEPTED',
            totalAmountEur: 48,
            totalSenderAmountEur: 54,
            totalNetAmountWithSupplementEur: 63,
            totalSenderAmountWithSupplementEur: 70.8,
            paymentMethod: BidPaymentMethod.cash,
            createdAt: DateTime(2026, 5),
            updatedAt: DateTime(2026, 5),
          ),
        );
        expect(
          find.text('${formatPriceIn(70.8, 'EUR')} en espèces'),
          findsOneWidget,
        );
        expect(
          find.textContaining('${formatPriceIn(63, 'EUR')} pour vous'),
          findsOneWidget,
        );
      },
    );

    for (final status in ['ACCEPTED', 'COMPLETED', 'PARCEL_REFUSED']) {
      testWidgets('XOF · $status → montant formaté en francs CFA', (
        tester,
      ) async {
        await _pump(
          tester,
          _bid(status: status, total: 20000, currency: 'XOF'),
        );
        expect(find.text(formatPriceIn(20000, 'XOF')), findsOneWidget);
        expect(find.textContaining('€'), findsNothing);
      });
    }

    testWidgets('montant indéterminable → « - » même colis refusé', (
      tester,
    ) async {
      await _pump(tester, _bid(status: 'PARCEL_REFUSED', total: null));
      expect(find.text('-'), findsOneWidget);
      expect(find.text('PAIEMENT'), findsOneWidget);
    });
  });
}
