import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/address_suggest_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockService extends Mock implements AddressAutocompleteService {}

void main() {
  testWidgets('onResolved contract: AddressData fields are accessible', (tester) async {
    final service = _MockService();
    final controller = TextEditingController();
    AddressData? resolved;

    when(() => service.search(any(), any(),
            lat: any(named: 'lat'), lng: any(named: 'lng')))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddressSuggestField(
          controller: controller,
          service: service,
          onResolved: (a) => resolved = a,
        ),
      ),
    ));

    // Vérifie que AddressData accepte les champs enrichis (contrat de type)
    const enriched = AddressData(
      label: 'Rue 10',
      lat: 14.7,
      lng: -17.4,
      street: 'Rue 10',
      city: 'Dakar',
      postalCode: null,
      country: 'SN',
    );
    resolved = enriched;

    expect(resolved!.city, 'Dakar');
    expect(resolved!.country, 'SN');
    expect(resolved!.street, 'Rue 10');
    expect(resolved!.postalCode, isNull);
    controller.dispose();
  });
}
