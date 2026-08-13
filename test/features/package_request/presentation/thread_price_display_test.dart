import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Unit tests for PriceDisplay.threadPriceLabel ────────────────────────────

void main() {
  // Épingle le taux de commission : ces tests assertent des montants
  // calculés à 12 % (indépendants du défaut kDonyCommissionRateDefault).
  setUpAll(() => setDonyCommissionRate(0.12));
  tearDownAll(() => setDonyCommissionRate(kDonyCommissionRateDefault));

  group('PriceDisplay.threadPriceLabel', () {
    test('traveler sees net amount formatted correctly', () {
      expect(
        PriceDisplay.threadPriceLabel(35, 39.20, true),
        'Tu reçois 35,00\u00A0€',
      );
    });

    test('sender sees gross amount when grossPriceEur provided', () {
      expect(
        PriceDisplay.threadPriceLabel(35, 39.20, false),
        'Tu paies 39,20\u00A0€',
      );
    });

    test('sender sees computed gross when grossPriceEur is null', () {
      // gross = 35 * 1.12 = 39.20
      expect(
        PriceDisplay.threadPriceLabel(35, null, false),
        'Tu paies 39,20\u00A0€',
      );
    });

    test('traveler ignores gross — always shows net', () {
      expect(
        PriceDisplay.threadPriceLabel(50, 60.0, true),
        'Tu reçois 50,00\u00A0€',
      );
    });

    test(
      'sender with null gross falls back to net*1.12 rounded to 2 decimals',
      () {
        // net = 100 → gross = 112.00
        expect(
          PriceDisplay.threadPriceLabel(100, null, false),
          'Tu paies 112,00\u00A0€',
        );
      },
    );
  });

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
    'ThreadMessageBubble — sender with proposedPriceEur=35, grossPriceEur=39.20 shows "Tu paies 39,20 €"',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          ThreadMessageBubble(
            message: makeMessage(proposedPriceEur: 35),
            mine: false,
            isTraveler: false,
            grossPriceEur: 39.20,
          ),
        ),
      );

      expect(find.text('Tu paies 39,20\u00A0€'), findsOneWidget);
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
