import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_radius_sheet.dart';

void main() {
  testWidgets('default radius is 25 km', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NearMeRadiusSheet()),
    ));
    expect(find.text('25 km'), findsOneWidget);
  });

  testWidgets('initialRadius reflected in label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NearMeRadiusSheet(initialRadiusKm: 60)),
    ));
    expect(find.text('60 km'), findsOneWidget);
  });

  testWidgets('Activer button returns the slider value via Navigator.pop',
      (tester) async {
    double? returned;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              returned = await showModalBottomSheet<double>(
                context: ctx,
                builder: (_) => const NearMeRadiusSheet(initialRadiusKm: 40),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activer le filtre'));
    await tester.pumpAndSettle();
    expect(returned, 40);
  });
}
