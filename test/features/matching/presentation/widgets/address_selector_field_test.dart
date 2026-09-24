import 'package:dony/features/matching/presentation/widgets/address_selector_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  Widget wrap(AddressSelectorType type) => MaterialApp(
    home: Scaffold(
      body: AddressSelectorField(type: type, onChanged: (_) {}),
    ),
  );

  group('en français', () {
    testWidgets('carte vide de remise', (tester) async {
      await tester.pumpWidget(wrap(AddressSelectorType.remise));

      expect(find.text('Choisir une adresse de remise'), findsOneWidget);
      expect(
        find.text('Où tu récupères les colis des expéditeurs'),
        findsOneWidget,
      );
    });

    testWidgets('carte vide de livraison', (tester) async {
      await tester.pumpWidget(wrap(AddressSelectorType.livraison));

      expect(find.text('Choisir une adresse de livraison'), findsOneWidget);
      expect(
        find.text('Où tu déposes les colis à destination'),
        findsOneWidget,
      );
    });
  });

  group('en anglais', () {
    testWidgets('carte vide de remise traduite', (tester) async {
      useEnglish();
      await tester.pumpWidget(wrap(AddressSelectorType.remise));

      expect(find.text('Choose a drop-off address'), findsOneWidget);
      expect(
        find.text('Where you collect parcels from senders'),
        findsOneWidget,
      );
    });

    testWidgets('carte vide de livraison traduite', (tester) async {
      useEnglish();
      await tester.pumpWidget(wrap(AddressSelectorType.livraison));

      expect(find.text('Choose a delivery address'), findsOneWidget);
      expect(
        find.text('Where you drop off parcels at destination'),
        findsOneWidget,
      );
    });
  });
}
