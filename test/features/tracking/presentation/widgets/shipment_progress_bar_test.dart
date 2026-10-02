import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/tracking/presentation/widgets/shipment_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<Color?>> colors(WidgetTester tester, int step) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ShipmentProgressBar(step: step)),
      ),
    );
    return tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(ShipmentProgressBar),
            matching: find.byType(Container),
          ),
        )
        .map((c) => (c.decoration as BoxDecoration?)?.color)
        .toList();
  }

  testWidgets('quatre segments, un par étape', (tester) async {
    expect(await colors(tester, 1), hasLength(ShipmentProgressBar.segments));
  });

  testWidgets('en route : 1 fait, 2 en cours, 3 et 4 à venir', (tester) async {
    final c = await colors(tester, 2);
    final cs = AppTheme.light().colorScheme;
    expect(c, [cs.primary, cs.secondary, cs.outline, cs.outline]);
  });

  // Sentry FLUTTER-6E : un colis remis restait à moitié vide.
  testWidgets('remis (étape 4) : tous les segments faits', (tester) async {
    final c = await colors(tester, 4);
    final cs = AppTheme.light().colorScheme;
    expect(c, List.filled(4, cs.primary));
  });
}
