import 'package:dony/core/design/design_system.dart';
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
    expect(find.byType(DonyMascotteAnimated), findsOneWidget);
    await tester.tap(find.text('Ajouter une carte'));
    expect(called, isTrue);

    // Draine les timers flutter_animate de la mascotte avant la fin du test.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
