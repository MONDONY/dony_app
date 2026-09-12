import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('marque connue : initiale et couleur de la marque', (
    tester,
  ) async {
    await pump(tester, const DonyBrandMark(brand: 'ORANGE'));
    expect(find.text('O'), findsOneWidget);
    final box = tester.widget<Container>(find.byType(Container).first);
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFFF7900));
    expect(decoration.borderRadius, BorderRadius.circular(10));
  });

  testWidgets('MTN affiche le sigle complet', (tester) async {
    await pump(tester, const DonyBrandMark(brand: 'MTN'));
    expect(find.text('MTN'), findsOneWidget);
  });

  testWidgets(
    'marque inconnue : première lettre sur la couleur primaire douce',
    (tester) async {
      await pump(tester, const DonyBrandMark(brand: 'expresso', size: 24));
      expect(find.text('E'), findsOneWidget);
      final box = tester.widget<Container>(find.byType(Container).first);
      final decoration = box.decoration! as BoxDecoration;
      final cs = Theme.of(
        tester.element(find.byType(DonyBrandMark)),
      ).colorScheme;
      expect(decoration.color, cs.primaryContainer);
    },
  );

  testWidgets('la pastille porte la marque en sémantique', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const DonyBrandMark(brand: 'WAVE'));
    expect(find.bySemanticsLabel('WAVE'), findsOneWidget);
    handle.dispose();
  });
}
