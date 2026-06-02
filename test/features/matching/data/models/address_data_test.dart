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

  group('AddressData equality (Equatable)', () {
    test('two identical instances are equal', () {
      const a = AddressData(
        label: 'Dakar',
        lat: 14.693,
        lng: -17.447,
        city: 'Dakar',
        country: 'SN',
      );
      const b = AddressData(
        label: 'Dakar',
        lat: 14.693,
        lng: -17.447,
        city: 'Dakar',
        country: 'SN',
      );
      expect(a, equals(b));
    });

    test('instances with different lat are not equal', () {
      const a = AddressData(label: 'A', lat: 1.0, lng: 2.0);
      const b = AddressData(label: 'A', lat: 9.9, lng: 2.0);
      expect(a, isNot(equals(b)));
    });

    test('props list has 7 elements', () {
      const a = AddressData(
        label: 'L',
        lat: 1.0,
        lng: 2.0,
        street: 's',
        city: 'c',
        postalCode: 'p',
        country: 'co',
      );
      expect(a.props.length, 7);
    });
  });

  group('AddressData.toJson', () {
    test('round-trips through toJson / fromJson', () {
      const original = AddressData(
        label: '12 Rue Victor Hugo',
        lat: 45.7484,
        lng: 4.8467,
        street: '12 Rue Victor Hugo',
        city: 'Lyon',
        postalCode: '69002',
        country: 'FR',
      );
      final json = original.toJson();
      final restored = AddressData.fromJson(json);
      expect(restored, equals(original));
    });

    test('toJson with null fields produces null values', () {
      const a = AddressData(label: 'Dakar', lat: 14.693, lng: -17.447);
      final json = a.toJson();
      expect(json['city'], isNull);
      expect(json['country'], isNull);
    });
  });

  group('AddressData.toString', () {
    test('returns a readable string', () {
      const a = AddressData(label: 'Lyon', lat: 45.7, lng: 4.8, city: 'Lyon');
      expect(a.toString(), contains('Lyon'));
    });
  });
}
