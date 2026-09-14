import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TripTemplate.fromJson', () {
    test('ancien contrat (avant V257) : défauts du formulaire vierge', () {
      final t = TripTemplate.fromJson({
        'id': 't1',
        'label': 'Paris-Dakar',
        'departureCity': 'Paris',
        'arrivalCity': 'Dakar',
        'transportMode': 'PLANE',
        'capacityUnit': 'SUITCASE_23KG',
        'availableKg': 23,
        'pricePerKg': 8.0,
        'acceptedCategories': ['Vêtements & tissus'],
        'cashAccepted': true,
        'arrivalTime': '06:30:00',
      });

      expect(t.currency, isNull);
      expect(t.pricingMode, 'KG');
      expect(t.pricePerKg, 8.0);
      // cashAccepted seul : STRIPE + CASH, comme le back le dérive.
      expect(t.acceptedPaymentMethods, ['STRIPE', 'CASH']);
      expect(t.negotiable, isFalse);
      expect(t.refusedTypes, isEmpty);
      expect(t.description, isNull);
      expect(t.pickupAddress, isNull);
      expect(t.deliveryAddress, isNull);
      expect(t.departureTime, isNull);
      expect(t.arrivalTime, '06:30');
      expect(t.handoverLeadDays, isNull);
      expect(t.departureCountryCode, isNull);
    });

    test('contrat complet : tous les champs lus', () {
      final t = TripTemplate.fromJson({
        'id': 't2',
        'label': 'Abidjan-Paris',
        'departureCity': 'Abidjan',
        'arrivalCity': 'Paris',
        'transportMode': 'PLANE',
        'capacityUnit': 'SUITCASE_23KG',
        'availableKg': 23,
        'pricePerKg': null,
        'acceptedCategories': [],
        'cashAccepted': true,
        'currency': 'XOF',
        'pricingMode': 'MIXED',
        'acceptedPaymentMethods': ['CASH', 'MOBILE_MONEY'],
        'negotiable': true,
        'refusedTypes': ['Téléphone & électronique'],
        'description': 'Pas de liquide',
        'pickupAddress': {'label': 'Cocody', 'lat': 5.35, 'lng': -3.99},
        'deliveryAddress': {'label': 'Gare de Lyon', 'lat': 48.84, 'lng': 2.37},
        'departureTime': '22:00:00',
        'handoverLeadDays': 2,
        'departureCountryCode': 'CI',
        'arrivalCountryCode': 'FR',
      });

      expect(t.currency, 'XOF');
      expect(t.pricingMode, 'MIXED');
      expect(t.usesPriceGrid, isTrue);
      expect(t.pricePerKg, isNull);
      expect(t.acceptedPaymentMethods, ['CASH', 'MOBILE_MONEY']);
      expect(t.negotiable, isTrue);
      expect(t.refusedTypes, ['Téléphone & électronique']);
      expect(t.description, 'Pas de liquide');
      expect(
        t.pickupAddress,
        const AddressData(label: 'Cocody', lat: 5.35, lng: -3.99),
      );
      expect(t.deliveryAddress?.label, 'Gare de Lyon');
      expect(t.departureTime, '22:00');
      expect(t.handoverLeadDays, 2);
      expect(t.departureCountryCode, 'CI');
      expect(t.arrivalCountryCode, 'FR');
    });

    test('acceptedPaymentMethods explicite prime sur cashAccepted', () {
      final t = TripTemplate.fromJson({
        'id': 't3',
        'label': 'x',
        'departureCity': 'a',
        'arrivalCity': 'b',
        'transportMode': 'PLANE',
        'capacityUnit': 'KG_FREE',
        'availableKg': 5,
        'pricePerKg': 5,
        'cashAccepted': true,
        'acceptedPaymentMethods': ['STRIPE'],
      });
      expect(t.acceptedPaymentMethods, ['STRIPE']);
      // La liste explicite prime totalement : le getter dérivé suit
      // acceptedPaymentMethods, jamais le drapeau brut cashAccepted quand la
      // liste est présente (cf. décision d'architecture du brief).
      expect(t.cashAccepted, isFalse);
    });
  });

  group('TripTemplate.toJson', () {
    test('envoie les nouveaux champs et cashAccepted en miroir', () {
      const t = TripTemplate(
        id: 't4',
        label: 'Abidjan-Paris',
        departureCity: 'Abidjan',
        arrivalCity: 'Paris',
        transportMode: 'PLANE',
        capacityUnit: 'SUITCASE_23KG',
        availableKg: 23,
        pricePerKg: 2000,
        acceptedCategories: ['Vêtements & tissus'],
        currency: 'XOF',
        acceptedPaymentMethods: ['CASH', 'MOBILE_MONEY'],
        negotiable: true,
        refusedTypes: ['Hi-fi'],
        description: 'Note',
        pickupAddress: AddressData(label: 'Cocody', lat: 5.35, lng: -3.99),
        departureTime: '22:00',
        arrivalTime: '06:30',
        handoverLeadDays: 2,
        departureCountryCode: 'CI',
        arrivalCountryCode: 'FR',
      );

      final json = t.toJson();

      expect(json['currency'], 'XOF');
      expect(json['pricingMode'], 'KG');
      expect(json['acceptedPaymentMethods'], ['CASH', 'MOBILE_MONEY']);
      expect(json['cashAccepted'], isTrue);
      expect(json['negotiable'], isTrue);
      expect(json['refusedTypes'], ['Hi-fi']);
      expect(json['description'], 'Note');
      expect(json['pickupAddress'], {
        'label': 'Cocody',
        'lat': 5.35,
        'lng': -3.99,
      });
      expect(json['deliveryAddress'], isNull);
      expect(json['departureTime'], '22:00');
      expect(json['handoverLeadDays'], 2);
      expect(json['departureCountryCode'], 'CI');
    });

    test('cashAccepted vaut false quand CASH est absent des moyens', () {
      const t = TripTemplate(
        id: 't5',
        label: 'x',
        departureCity: 'a',
        arrivalCity: 'b',
        transportMode: 'PLANE',
        capacityUnit: 'KG_FREE',
        availableKg: 5,
        pricePerKg: 5,
        acceptedCategories: [],
        acceptedPaymentMethods: ['STRIPE'],
      );
      expect(t.toJson()['cashAccepted'], isFalse);
    });
  });
}
