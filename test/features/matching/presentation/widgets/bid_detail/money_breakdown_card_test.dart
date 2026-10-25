import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_money_breakdown.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/money_breakdown_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/paiement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MoneyLine _line(
  MoneyLineKind kind,
  String method,
  double amount, {
  String status = 'SECURED',
}) => MoneyLine(
  kind: kind,
  refId: 'r-$method-$amount',
  method: method,
  amount: amount,
  status: status,
);

BidModel _bid(
  BidMoneyBreakdown? breakdown, {
  String status = 'ACCEPTED',
  String senderName = 'Aïcha',
  BidPaymentMethod method = BidPaymentMethod.stripe,
}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: status,
  weightKg: 5,
  totalAmountEur: 48,
  totalSenderAmountEur: 54,
  paymentMethod: method,
  senderName: senderName,
  travelerName: 'Moussa',
  moneyBreakdown: breakdown,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

// Voyageur : nets 54 (carte) + 23,50 (espèces) = 77,50 ; brut espèces 26,80.
final _travelerCashBreakdown = BidMoneyBreakdown(
  lines: [
    _line(MoneyLineKind.principal, 'STRIPE', 54),
    _line(MoneyLineKind.amendment, 'CASH', 23.5),
  ],
  total: 77.5,
  onlineAmount: 54,
  cashAmount: 26.8,
  cashCommissionPaid: 3.3,
);

// Expéditeur : bruts 61,20 (carte) + 26,80 (espèces) = 88,00.
final _senderCashBreakdown = BidMoneyBreakdown(
  lines: [
    _line(MoneyLineKind.principal, 'STRIPE', 61.2),
    _line(MoneyLineKind.amendment, 'CASH', 26.8),
  ],
  total: 88,
  onlineAmount: 61.2,
  cashAmount: 26.8,
);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  group('MoneyBreakdownCard', () {
    testWidgets('traveler_cardPlusCash_showsBothDestinations', (tester) async {
      await _pump(
        tester,
        MoneyBreakdownCard(bid: _bid(_travelerCashBreakdown), isSender: false),
      );
      expect(find.text('CE QUE VOUS RECEVEZ'), findsOneWidget);
      expect(find.text('Demande initiale · carte'), findsOneWidget);
      expect(find.text('Modification · espèces'), findsOneWidget);
      expect(find.text('54,00\u00a0€'), findsNWidgets(2)); // ligne + versé
      expect(find.text('23,50\u00a0€'), findsOneWidget);
      expect(find.text('Total pour vous'), findsOneWidget);
      expect(find.text('77,50\u00a0€'), findsOneWidget);
      expect(
        find.text('Versé sur votre compte après la livraison'),
        findsOneWidget,
      );
      expect(
        find.text('À récupérer en espèces auprès d\'Aïcha'),
        findsOneWidget,
      );
      expect(find.text('26,80\u00a0€'), findsOneWidget); // destination espèces
      expect(find.textContaining('dont 3,30\u00a0€'), findsOneWidget);
      expect(
        find.text(
          'À la remise, récupérez 26,80\u00a0€ en espèces avant de scanner le QR du colis.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('traveler_afterHandover_noHandoverNote', (tester) async {
      await _pump(
        tester,
        MoneyBreakdownCard(
          bid: _bid(_travelerCashBreakdown, status: 'HANDED_OVER'),
          isSender: false,
        ),
      );
      expect(find.textContaining('avant de scanner'), findsNothing);
      expect(
        find.text('À récupérer en espèces auprès d\'Aïcha'),
        findsOneWidget,
      );
    });

    testWidgets('traveler_cardPlusCard_singleDestination', (tester) async {
      final b = BidMoneyBreakdown(
        lines: [
          _line(MoneyLineKind.principal, 'STRIPE', 54),
          _line(MoneyLineKind.amendment, 'STRIPE', 20),
        ],
        total: 74,
        onlineAmount: 74,
        cashAmount: 0,
      );
      await _pump(tester, MoneyBreakdownCard(bid: _bid(b), isSender: false));
      expect(
        find.text('Versé sur votre compte après la livraison'),
        findsOneWidget,
      );
      expect(find.textContaining('en espèces'), findsNothing);
      expect(find.textContaining('avant de scanner'), findsNothing);
      expect(find.textContaining('dont'), findsNothing);
      expect(find.text('74,00\u00a0€'), findsNWidgets(2));
    });

    testWidgets('sender_neverShowsNet', (tester) async {
      await _pump(
        tester,
        MoneyBreakdownCard(bid: _bid(_senderCashBreakdown), isSender: true),
      );
      expect(find.text('PAIEMENT'), findsOneWidget);
      expect(find.text('Colis initial · carte'), findsOneWidget);
      expect(find.text('Modification · espèces'), findsOneWidget);
      expect(find.text('61,20\u00a0€'), findsNWidgets(2));
      expect(find.text('Total du colis'), findsOneWidget);
      expect(find.text('88,00\u00a0€'), findsOneWidget);
      expect(
        find.text('Payé par carte, gardé jusqu\'à la livraison'),
        findsOneWidget,
      );
      expect(find.text('À remettre en espèces à Moussa'), findsOneWidget);
      expect(find.text('26,80\u00a0€'), findsNWidgets(2));
      // Ni net, ni commission, ni note voyageur.
      expect(find.text('54,00\u00a0€'), findsNothing);
      expect(find.text('23,50\u00a0€'), findsNothing);
      expect(find.textContaining('commission'), findsNothing);
      expect(find.textContaining('avant de scanner'), findsNothing);
    });

    testWidgets('sender_mobileMoneyOnline_saysPaidOnline', (tester) async {
      final b = BidMoneyBreakdown(
        lines: [_line(MoneyLineKind.principal, 'MOBILE_MONEY', 61.2)],
        total: 61.2,
        onlineAmount: 61.2,
        cashAmount: 0,
      );
      await _pump(tester, MoneyBreakdownCard(bid: _bid(b), isSender: true));
      expect(
        find.text('Payé en ligne, gardé jusqu\'à la livraison'),
        findsOneWidget,
      );
      expect(find.textContaining('par carte'), findsNothing);
    });

    testWidgets('traveler_consonantName_usesDe', (tester) async {
      await _pump(
        tester,
        MoneyBreakdownCard(
          bid: _bid(_travelerCashBreakdown, senderName: 'Moussa'),
          isSender: false,
        ),
      );
      expect(
        find.text('À récupérer en espèces auprès de Moussa'),
        findsOneWidget,
      );
    });

    testWidgets('traveler_hName_elides', (tester) async {
      await _pump(
        tester,
        MoneyBreakdownCard(
          bid: _bid(_travelerCashBreakdown, senderName: 'Hawa'),
          isSender: false,
        ),
      );
      expect(find.text("À récupérer en espèces auprès d'Hawa"), findsOneWidget);
    });

    testWidgets('unknownMethod_neutralLabelAndIcon', (tester) async {
      final b = BidMoneyBreakdown(
        lines: [_line(MoneyLineKind.principal, 'CRYPTO', 61.2)],
        total: 61.2,
        onlineAmount: 61.2,
        cashAmount: 0,
      );
      await _pump(tester, MoneyBreakdownCard(bid: _bid(b), isSender: true));
      expect(find.text('Colis initial · autre moyen'), findsOneWidget);
      expect(find.textContaining('carte'), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'wallet'),
        findsOneWidget,
      );
    });

    testWidgets('sender_cardAndMobileMoneyMix_saysPaidOnline', (tester) async {
      final b = BidMoneyBreakdown(
        lines: [
          _line(MoneyLineKind.principal, 'STRIPE', 61.2),
          _line(MoneyLineKind.amendment, 'MOBILE_MONEY', 10),
        ],
        total: 71.2,
        onlineAmount: 71.2,
        cashAmount: 0,
      );
      await _pump(tester, MoneyBreakdownCard(bid: _bid(b), isSender: true));
      expect(
        find.text("Payé en ligne, gardé jusqu'à la livraison"),
        findsOneWidget,
      );
      expect(find.textContaining('par carte'), findsNothing);
    });

    testWidgets('pendingLine_showsBadge_excludedFromTotal', (tester) async {
      final b = BidMoneyBreakdown(
        lines: [
          _line(MoneyLineKind.principal, 'STRIPE', 61.2),
          _line(MoneyLineKind.amendment, 'STRIPE', 12, status: 'PENDING'),
        ],
        total: 61.2,
        onlineAmount: 61.2,
        cashAmount: 0,
      );
      await _pump(tester, MoneyBreakdownCard(bid: _bid(b), isSender: true));
      expect(find.text('EN ATTENTE'), findsOneWidget);
      expect(find.text('12,00\u00a0€'), findsOneWidget);
      // Le total affiché est celui du serveur : 61,20 (ligne + total + gardé).
      expect(find.text('61,20\u00a0€'), findsNWidgets(3));
    });

    testWidgets('supplementLine_hasOwnLabel', (tester) async {
      final b = BidMoneyBreakdown(
        lines: [
          _line(MoneyLineKind.principal, 'STRIPE', 61.2),
          _line(MoneyLineKind.supplement, 'STRIPE', 8),
        ],
        total: 69.2,
        onlineAmount: 69.2,
        cashAmount: 0,
      );
      await _pump(tester, MoneyBreakdownCard(bid: _bid(b), isSender: true));
      expect(find.text('Supplément de prix · carte'), findsOneWidget);
    });
  });

  group('délégation et non-régression', () {
    testWidgets('paiementCard_withBreakdown_delegates', (tester) async {
      await _pump(tester, PaiementCard(bid: _bid(_senderCashBreakdown)));
      expect(find.byType(MoneyBreakdownCard), findsOneWidget);
      expect(find.text('Total du colis'), findsOneWidget);
    });

    testWidgets('paiementCard_withoutBreakdown_unchanged', (tester) async {
      await _pump(tester, PaiementCard(bid: _bid(null)));
      expect(find.byType(MoneyBreakdownCard), findsNothing);
      expect(find.text('Paiement'), findsOneWidget);
      expect(
        find.text(
          '${formatPriceIn(54, 'EUR')} séquestré : libéré à la livraison',
        ),
        findsOneWidget,
      );
    });

    testWidgets('travelerGainCard_withBreakdown_delegates', (tester) async {
      await _pump(tester, TravelerGainCard(bid: _bid(_travelerCashBreakdown)));
      expect(find.byType(MoneyBreakdownCard), findsOneWidget);
      expect(find.text('Total pour vous'), findsOneWidget);
    });

    testWidgets('travelerGainCard_withoutBreakdown_unchanged', (tester) async {
      await _pump(tester, TravelerGainCard(bid: _bid(null)));
      expect(find.byType(MoneyBreakdownCard), findsNothing);
      expect(find.text('Total pour vous'), findsNothing);
      expect(find.text(formatPriceIn(48, 'EUR')), findsOneWidget);
    });
  });
}
