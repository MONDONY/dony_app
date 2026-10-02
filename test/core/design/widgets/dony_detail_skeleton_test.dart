import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Sentry FLUTTER-4M : ~450 dp de squelette dans un body de 427 dp
  // (petit écran + barre d'action) débordaient de 26 px.
  testWidgets('squelette détail : aucun débordement dans un espace réduit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(height: 300, child: DonyDetailSkeleton()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byType(DonyDetailSkeleton), findsOneWidget);
  });
}
