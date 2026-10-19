import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid({
  required String status,
  double? total = 48,
  double? senderTotal,
  BidPaymentMethod method = BidPaymentMethod.stripe,
  String currency = 'EUR',
}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: status,
  weightKg: 5,
  totalAmountEur: total,
  totalSenderAmountEur: senderTotal,
  paymentMethod: method,
  currency: currency,
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
      find.text('Frais de service Yadony prélevés séparément.'),
      findsOneWidget,
    );
    expect(find.textContaining('Vous gardez'), findsNothing);
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
        'Dont ${formatPriceIn(2.4, 'EUR')} de frais de service Yadony, prélevés sur '
        'votre solde ou votre carte. Vous gardez ${formatPriceIn(48, 'EUR')}.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Frais de service Yadony prélevés séparément.'),
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
      find.textContaining('Vous gardez ${formatPriceIn(20000, 'XOF')}'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Dont ${formatPriceIn(1000, 'XOF')} de frais de service',
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
    expect(find.textContaining('Vous gardez'), findsNothing);
    expect(
      find.text('Frais de service Yadony prélevés séparément.'),
      findsOneWidget,
    );
  });

  testWidgets('Stripe avec brut → toujours le net, sans détail espèces', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'ACCEPTED', senderTotal: 50.4));
    expect(find.text(formatPriceIn(48, 'EUR')), findsOneWidget);
    expect(find.textContaining('Vous gardez'), findsNothing);
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
}
