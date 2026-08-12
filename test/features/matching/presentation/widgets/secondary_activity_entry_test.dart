import 'package:dony/features/matching/presentation/widgets/secondary_activity_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows label and fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SecondaryActivityEntry(
          icon: Icons.flight_takeoff_rounded,
          label: 'Mes trajets',
          onTap: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('Mes trajets'), findsOneWidget);
    await tester.tap(find.byType(SecondaryActivityEntry));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
