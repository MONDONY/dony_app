import 'package:dony/core/design/design_system.dart';
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
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      );

  group('ThreadMessageBubble', () {
    testWidgets('mine=true → bulle primary solide avec prix + label CAPS',
        (tester) async {
      await tester.pumpWidget(wrap(ThreadMessageBubble(
        message: _msg(kind: NegotiationMessageKind.proposal),
        mine: true,
      )));
      expect(find.text('PROPOSITION'), findsOneWidget);
      expect(find.text('35 €'), findsOneWidget);
      expect(find.text('09:51'), findsOneWidget);
    });

    testWidgets('mine=false → bulle surface avec border', (tester) async {
      await tester.pumpWidget(wrap(ThreadMessageBubble(
        message: _msg(kind: NegotiationMessageKind.counter, price: 30),
        mine: false,
      )));
      expect(find.text('CONTRE-OFFRE'), findsOneWidget);
      expect(find.text('30 €'), findsOneWidget);
    });

    testWidgets('rend body en italique si fourni', (tester) async {
      await tester.pumpWidget(wrap(ThreadMessageBubble(
        message: _msg(
          kind: NegotiationMessageKind.counter,
          body: 'Je peux pas plus, c\'est urgent',
        ),
        mine: false,
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
      )));
      expect(find.text('NOUVEAU'), findsOneWidget);
    });

    testWidgets('highlight=true + mine=true → pas de badge NOUVEAU',
        (tester) async {
      await tester.pumpWidget(wrap(ThreadMessageBubble(
        message: _msg(kind: NegotiationMessageKind.counter, price: 30),
        mine: true,
        highlight: true,
      )));
      expect(find.text('NOUVEAU'), findsNothing);
    });

    testWidgets('prix absent → pas de "€"', (tester) async {
      await tester.pumpWidget(wrap(ThreadMessageBubble(
        message: _msg(kind: NegotiationMessageKind.reject, price: null),
        mine: false,
      )));
      expect(find.textContaining('€'), findsNothing);
      expect(find.text('REJETÉE'), findsOneWidget);
    });
  });
}
