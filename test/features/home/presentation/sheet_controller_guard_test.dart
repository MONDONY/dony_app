import 'package:dony/features/home/presentation/sheet_controller_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('feuille détachée : aucune assertion, geste appliqué au '
      'rattachement', (tester) async {
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    expect(controller.isAttached, isFalse);

    // Détaché : ni assertion ni effet.
    moveSheetWhenAttached(
      controller,
      0,
      isMounted: () => true,
      duration: const Duration(milliseconds: 100),
    );
    expect(tester.takeException(), isNull);

    // Le défilant se monte quelques frames plus tard.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DraggableScrollableSheet(
            controller: controller,
            initialChildSize: 1,
            minChildSize: 0,
            builder: (_, scroll) =>
                ListView(controller: scroll, children: const [Text('x')]),
          ),
        ),
      ),
    );
    expect(controller.isAttached, isTrue);
    expect(controller.size, 1);

    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(controller.size, 0);
  });

  testWidgets('jamais rattachée : abandon après les frames de reprise, '
      'sans exception', (tester) async {
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(const SizedBox());

    moveSheetWhenAttached(controller, 1, isMounted: () => true);
    for (var i = 0; i < kSheetAttachRetryFrames + 2; i++) {
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    expect(controller.isAttached, isFalse);
  });

  testWidgets('écran démonté : le geste est abandonné', (tester) async {
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(const SizedBox());

    moveSheetWhenAttached(controller, 1, isMounted: () => false);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
