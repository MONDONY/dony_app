import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AddressData.fromJson', () {
    test('parses enriched structured fields', () {
      final json = {
        'label': '12 Rue Victor Hugo',
        'lat': 45.7484,
        'lng': 4.8467,
        'street': '12 Rue Victor Hugo',
        'city': 'Lyon',
        'postalCode': '69002',
        'country': 'FR',
      };

      final a = AddressData.fromJson(json);

      expect(a.label, '12 Rue Victor Hugo');
      expect(a.lat, 45.7484);
      expect(a.street, '12 Rue Victor Hugo');
      expect(a.city, 'Lyon');
      expect(a.postalCode, '69002');
      expect(a.country, 'FR');
    });

    test('missing structured fields default to null', () {
      final a = AddressData.fromJson({
        'label': 'Dakar, Sénégal',
        'lat': 14.693,
        'lng': -17.447,
      });

      expect(a.city, isNull);
      expect(a.street, isNull);
      expect(a.postalCode, isNull);
      expect(a.country, isNull);
    });
  });
}
