import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid({
  required String status,
  double? total = 48,
  BidPaymentMethod method = BidPaymentMethod.stripe,
}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: status,
  weightKg: 5,
  totalAmountEur: total,
  paymentMethod: method,
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

  testWidgets('Cash → encaissement en espèces', (tester) async {
    await _pump(
      tester,
      _bid(status: 'ACCEPTED', method: BidPaymentMethod.cash),
    );
    expect(find.text('VOUS ENCAISSEZ'), findsOneWidget);
    expect(find.textContaining('espèces'), findsOneWidget);
  });
}
