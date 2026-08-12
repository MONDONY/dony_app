import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

BidModel _makeBid({
  required String status,
  required BidPaymentMethod paymentMethod,
}) {
  return BidModel(
    id: 'bid-001',
    announcementId: 'ann-001',
    senderId: 'sender-001',
    weightKg: 5,
    status: status,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
    paymentMethod: paymentMethod,
  );
}

Widget _wrap(BidModel bid) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: SenderActionBar(
              bid: bid,
              isLoading: false,
              paymentLoaded: true,
              // existingPayment intentionally null → "Payer mon envoi" branch
              // for stripe, cash badge branch for cash.
            ),
          ),
        ),
        // SenderActionBar pushes here for stripe bids; route must exist.
        GoRoute(
          path: '/payments/pay',
          builder: (_, __) => const Scaffold(body: Text('pay-screen')),
        ),
      ],
    ),
  );
}

void main() {
  group('SenderActionBar — paiement selon le mode', () {
    testWidgets(
      'CASH (ACCEPTED, paymentLoaded, no payment) → pas de "Payer mon envoi", '
      'badge espèces affiché',
      (tester) async {
        final bid = _makeBid(
          status: 'ACCEPTED',
          paymentMethod: BidPaymentMethod.cash,
        );

        await tester.pumpWidget(_wrap(bid));
        await tester.pumpAndSettle();

        expect(find.text('Payer mon envoi'), findsNothing);
        expect(find.text('Paiement en espèces à la remise'), findsOneWidget);
        expect(
          find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'banknote'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'STRIPE (ACCEPTED, paymentLoaded, no payment) → "Payer mon envoi" affiché, '
      'pas de badge espèces',
      (tester) async {
        final bid = _makeBid(
          status: 'ACCEPTED',
          paymentMethod: BidPaymentMethod.stripe,
        );

        await tester.pumpWidget(_wrap(bid));
        await tester.pumpAndSettle();

        expect(find.text('Payer mon envoi'), findsOneWidget);
        expect(find.text('Paiement en espèces à la remise'), findsNothing);
      },
    );

    testWidgets('WAVE → traité comme espèces (pas de "Payer mon envoi")', (
      tester,
    ) async {
      final bid = _makeBid(
        status: 'PENDING',
        paymentMethod: BidPaymentMethod.wave,
      );

      await tester.pumpWidget(_wrap(bid));
      await tester.pumpAndSettle();

      expect(find.text('Payer mon envoi'), findsNothing);
      expect(find.text('Paiement en espèces à la remise'), findsOneWidget);
    });
  });
}
