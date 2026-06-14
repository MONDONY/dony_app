import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/cash/presentation/widgets/commission_card_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows add button and calls onAdd when tapped', (tester) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommissionCardEmptyState(onAdd: () => called = true),
        ),
      ),
    );
    expect(find.text('Ajouter une carte'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'credit-card'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ajouter une carte'));
    expect(called, isTrue);
  });
}
