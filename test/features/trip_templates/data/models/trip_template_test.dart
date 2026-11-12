import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
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
      expect(t.arrivalDayOffset, 0);
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
        'arrivalDayOffset': 1,
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
      expect(t.arrivalDayOffset, 1);
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
        arrivalDayOffset: 1,
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
      expect(json['arrivalDayOffset'], 1);
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

  group('TripTemplate : taille et poids max par colis', () {
    Map<String, dynamic> json([Map<String, dynamic> extra = const {}]) => {
      'id': 't1',
      'label': 'Paris-Dakar route',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'transportMode': 'CAR',
      'capacityUnit': 'KG_FREE',
      'availableKg': 1200,
      'pricePerKg': 3,
      ...extra,
    };

    test('contrat antérieur (clés absentes) : null', () {
      final t = TripTemplate.fromJson(json());
      expect(t.maxItemSize, isNull);
      expect(t.maxParcelWeightKg, isNull);
      expect(t.availableKg, 1200);
    });

    test('taille L et poids max entier JSON 20 : lus', () {
      final t = TripTemplate.fromJson(
        json({'maxItemSize': 'L', 'maxParcelWeightKg': 20}),
      );
      expect(t.maxItemSize, ItemSize.l);
      expect(t.maxParcelWeightKg, 20.0);
    });

    test('taille inconnue : null, sans exception', () {
      expect(
        TripTemplate.fromJson(json({'maxItemSize': 'XXL'})).maxItemSize,
        isNull,
      );
    });

    test('poids max à 999 999,99 sans perte', () {
      expect(
        TripTemplate.fromJson(
          json({'maxParcelWeightKg': 999999.99}),
        ).maxParcelWeightKg,
        999999.99,
      );
    });

    test('toJson (création) : clés écrites seulement si renseignées', () {
      final empty = TripTemplate.fromJson(json()).toJson();
      expect(empty.containsKey('maxItemSize'), isFalse);
      expect(empty.containsKey('maxParcelWeightKg'), isFalse);

      final full = TripTemplate.fromJson(
        json({'maxItemSize': 'M', 'maxParcelWeightKg': 12.5}),
      ).toJson();
      expect(full['maxItemSize'], 'M');
      expect(full['maxParcelWeightKg'], 12.5);
    });

    test('toUpdateJson : valeurs renseignées envoyées', () {
      final body = TripTemplate.fromJson(
        json({'maxItemSize': 'XL', 'maxParcelWeightKg': 8}),
      ).toUpdateJson();
      expect(body['maxItemSize'], 'XL');
      expect(body['maxParcelWeightKg'], 8.0);
    });

    test('toUpdateJson : aucune limite = sentinelles NONE et 0', () {
      final body = TripTemplate.fromJson(json()).toUpdateJson();
      expect(body['maxItemSize'], 'NONE');
      expect(body['maxParcelWeightKg'], 0);
    });

    test('toUpdateJson garde le reste du corps de toJson', () {
      final t = TripTemplate.fromJson(json());
      final update = t.toUpdateJson()
        ..remove('maxItemSize')
        ..remove('maxParcelWeightKg');
      expect(update, t.toJson());
    });
  });
}
