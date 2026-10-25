import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('n\'a aucun effet sur la mise en page ni sur le contenu', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(width: 200, child: TextField()),
              SizedBox(width: 200, child: DonyReplayMask(child: TextField())),
            ],
          ),
        ),
      ),
    );
    final sizes = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((w) => tester.getSize(find.byWidget(w)))
        .toList();
    expect(sizes, hasLength(2));
    expect(sizes[0], sizes[1]);
  });

  testWidgets('DonyTextField : le champ reste utilisable', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DonyTextField(controller: controller)),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'abc');
    expect(controller.text, 'abc');
  });
}
