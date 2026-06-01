import 'package:dony/core/widgets/address/address_label_chips.dart';
import 'package:dony/core/widgets/address/address_location_status.dart';
import 'package:dony/core/widgets/address/address_section_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AddressSectionLabel renders uppercase text', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AddressSectionLabel('Étiquette')),
    ));
    expect(find.text('ÉTIQUETTE'), findsOneWidget);
  });

  testWidgets('AddressLabelChips fills controller on tap', (tester) async {
    final controller = TextEditingController();
    var changed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddressLabelChips(
          controller: controller,
          chips: const ['Maison', 'Bureau'],
          accentColor: Colors.blue,
          onSelected: () => changed = true,
        ),
      ),
    ));

    await tester.tap(find.text('Bureau'));
    await tester.pump();

    expect(controller.text, 'Bureau');
    expect(changed, isTrue);
    controller.dispose();
  });

  testWidgets('AddressLocationStatus shows localized label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AddressLocationStatus(state: AddressLocationState.localized),
      ),
    ));
    expect(find.text('Adresse localisée'), findsOneWidget);
  });

  testWidgets('AddressLocationStatus hidden renders nothing', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AddressLocationStatus(state: AddressLocationState.hidden),
      ),
    ));
    expect(find.textContaining('localisée'), findsNothing);
  });
}
