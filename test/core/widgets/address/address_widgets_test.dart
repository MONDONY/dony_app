import 'package:dony/core/widgets/address/address_default_toggle.dart';
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

  testWidgets('AddressLocationStatus manual shows correct label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AddressLocationStatus(state: AddressLocationState.manual),
      ),
    ));
    expect(find.textContaining('non localisée'), findsOneWidget);
  });

  group('AddressDefaultToggle', () {
    testWidgets('renders with value=false (not active)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AddressDefaultToggle(
            value: false,
            onChanged: (_) {},
            activeColor: Colors.blue,
            subtitle: 'Pré-remplie lors des prochaines demandes',
          ),
        ),
      ));
      expect(find.text('Adresse par défaut'), findsOneWidget);
      expect(find.text('Pré-remplie lors des prochaines demandes'), findsOneWidget);
    });

    testWidgets('renders with value=true (active)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AddressDefaultToggle(
            value: true,
            onChanged: (_) {},
            activeColor: Colors.blue,
            subtitle: 'Sous-titre actif',
          ),
        ),
      ));
      expect(find.text('Adresse par défaut'), findsOneWidget);
    });

    testWidgets('calls onChanged with !value on tap', (tester) async {
      bool? received;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AddressDefaultToggle(
            value: false,
            onChanged: (v) => received = v,
            activeColor: Colors.blue,
            subtitle: 'Test',
          ),
        ),
      ));

      // Tap the GestureDetector (the whole card)
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(received, isTrue);
    });

    testWidgets('tapping Switch also calls onChanged', (tester) async {
      bool? received;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AddressDefaultToggle(
            value: false,
            onChanged: (v) => received = v,
            activeColor: Colors.blue,
            subtitle: 'Test',
          ),
        ),
      ));

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(received, isTrue);
    });
  });

  group('AddressLabelChips — multiple chips', () {
    testWidgets('tapping a chip sets controller to that label', (tester) async {
      final controller = TextEditingController();
      var callCount = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AddressLabelChips(
            controller: controller,
            chips: const ['Maison', 'Bureau', 'Boutique'],
            accentColor: Colors.blue,
            onSelected: () => callCount++,
          ),
        ),
      ));

      await tester.tap(find.text('Boutique'));
      await tester.pump();

      expect(controller.text, 'Boutique');
      expect(callCount, 1);
      controller.dispose();
    });

    testWidgets('tapping a different chip switches selection', (tester) async {
      final controller = TextEditingController(text: 'Maison');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AddressLabelChips(
            controller: controller,
            chips: const ['Maison', 'Bureau'],
            accentColor: Colors.blue,
            onSelected: () {},
          ),
        ),
      ));

      await tester.tap(find.text('Bureau'));
      await tester.pump();

      expect(controller.text, 'Bureau');
      controller.dispose();
    });
  });
}
