import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Les tests unitaires de `threadPriceLabel` (ex-`PriceDisplay.threadPriceLabel`) vivent désormais dans package_request_labels_test.dart,
// dans les deux langues. Ce fichier ne garde que les tests de widget
// ci-dessous.

void main() {
  // Épingle le taux de commission : ces tests assertent des montants
  // calculés à 12 % (indépendants du défaut kDonyCommissionRateDefault).
  setUpAll(() => setDonyCommissionRate(0.12));
  tearDownAll(() => setDonyCommissionRate(kDonyCommissionRateDefault));

  // ─── Widget tests for ThreadMessageBubble ──────────────────────────────────

  NegotiationMessage makeMessage({double? proposedPriceEur}) =>
      NegotiationMessage(
        id: 'msg-1',
        threadId: 'thread-1',
        fromUserId: 'user-traveler',
        kind: NegotiationMessageKind.proposal,
        proposedPriceEur: proposedPriceEur,
        createdAt: DateTime(2026, 6, 1, 10, 30),
      );

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets(
    'ThreadMessageBubble — traveler with proposedPriceEur=35 shows "Tu reçois 35,00 €"',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          ThreadMessageBubble(
            message: makeMessage(proposedPriceEur: 35),
            mine: true,
            isTraveler: true,
          ),
        ),
      );

      expect(find.text('Tu reçois 35,00\u00A0€'), findsOneWidget);
    },
  );

  testWidgets(
    'ThreadMessageBubble — sender with grossPriceEur=null computes gross from net (35 → 39,20 €)',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          ThreadMessageBubble(
            message: makeMessage(proposedPriceEur: 35),
            mine: false,
            isTraveler: false,
            // grossPriceEur intentionally omitted (null)
          ),
        ),
      );

      // gross = 35 * 1.12 = 39.20
      expect(find.text('Tu paies 39,20\u00A0€'), findsOneWidget);
    },
  );

  testWidgets(
    'ThreadMessageBubble — no price displayed when proposedPriceEur is null',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          ThreadMessageBubble(
            message: makeMessage(),
            mine: false,
            isTraveler: false,
          ),
        ),
      );

      expect(find.textContaining('Tu'), findsNothing);
    },
  );
}
