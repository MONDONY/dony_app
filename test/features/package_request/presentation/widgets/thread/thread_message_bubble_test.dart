import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

NegotiationMessage _msg({
  required NegotiationMessageKind kind,
  double? price = 35,
  String? body,
  String fromUserId = 'other-user',
}) =>
    NegotiationMessage(
      id: 'm1',
      threadId: 't1',
      fromUserId: fromUserId,
      kind: kind,
      proposedPriceEur: price,
      body: body,
      createdAt: DateTime(2026, 5, 11, 9, 51),
    );

void main() {
  // Épingle le taux de commission : ces tests assertent des montants
  // calculés à 12 % (indépendants du défaut kDonyCommissionRateDefault).
  setUpAll(() => setDonyCommissionRate(0.12));
  tearDownAll(() => setDonyCommissionRate(kDonyCommissionRateDefault));

  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      );

  group('ThreadMessageBubble', () {
    testWidgets(
        'mine=true, isTraveler=true → bulle primary solide avec prix net + label CAPS',
        (tester) async {
      await tester.pumpWidget(wrap(ThreadMessageBubble(
        message: _msg(kind: NegotiationMessageKind.proposal),
        mine: true,
        isTraveler: true,
      )));
      expect(find.text('PROPOSITION'), findsOneWidget);
      // Traveler sees net: "Tu reçois 35,00 €"
      expect(find.text('Tu reçois 35,00 €'), findsOneWidget);
      expect(find.text('09:51'), findsOneWidget);
    });

    testWidgets('mine=false, isTraveler=false → bulle surface avec prix gross',
        (tester) async {
      await tester.pumpWidget(wrap(ThreadMessageBubble(
        message: _msg(kind: NegotiationMessageKind.counter, price: 30),
        mine: false,
        isTraveler: false,
        // gross = 30 * 1.12 = 33.60
      )));
      expect(find.text('CONTRE-OFFRE'), findsOneWidget);
      expect(find.text('Tu paies 33,60 €'), findsOneWidget);
    });

    testWidgets('rend body si fourni', (tester) async {
      await tester.pumpWidget(wrap(ThreadMessageBubble(
        message: _msg(
          kind: NegotiationMessageKind.counter,
          body: 'Je peux pas plus, c\'est urgent',
        ),
        mine: false,
        isTraveler: false,
      )));
      expect(find.text('Je peux pas plus, c\'est urgent'), findsOneWidget);
    });

    testWidgets('rend les 4 kinds avec labels FR corrects', (tester) async {
      for (final pair in [
        (NegotiationMessageKind.proposal, 'PROPOSITION'),
        (NegotiationMessageKind.counter, 'CONTRE-OFFRE'),
        (NegotiationMessageKind.accept, 'ACCEPTÉE'),
        (NegotiationMessageKind.reject, 'REJETÉE'),
      ]) {
        await tester.pumpWidget(wrap(ThreadMessageBubble(
          message: _msg(kind: pair.$1, price: null),
          mine: false,
          isTraveler: false,
        )));
        expect(find.text(pair.$2), findsOneWidget,
            reason: 'Label attendu pour ${pair.$1}');
      }
    });

    testWidgets('highlight=true + mine=false → badge NOUVEAU rendu',
        (tester) async {
      await tester.pumpWidget(wrap(ThreadMessageBubble(
        message: _msg(kind: NegotiationMessageKind.counter, price: 38),
        mine: false,
        highlight: true,
        isTraveler: false,
      )));
      expect(find.text('NOUVEAU'), findsOneWidget);
    });

    testWidgets('highlight=true + mine=true → pas de badge NOUVEAU',
        (tester) async {
      await tester.pumpWidget(wrap(ThreadMessageBubble(
        message: _msg(kind: NegotiationMessageKind.counter, price: 30),
        mine: true,
        highlight: true,
        isTraveler: true,
      )));
      expect(find.text('NOUVEAU'), findsNothing);
    });

    testWidgets('prix absent → pas de "€"', (tester) async {
      await tester.pumpWidget(wrap(ThreadMessageBubble(
        message: _msg(kind: NegotiationMessageKind.reject, price: null),
        mine: false,
        isTraveler: false,
      )));
      expect(find.textContaining('€'), findsNothing);
      expect(find.text('REJETÉE'), findsOneWidget);
    });
  });
}
