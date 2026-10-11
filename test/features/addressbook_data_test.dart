import 'package:dio/dio.dart';
import 'package:dony/features/delivery_addresses/data/datasources/delivery_address_datasource.dart';
import 'package:dony/features/delivery_addresses/data/models/delivery_address.dart';
import 'package:dony/features/delivery_addresses/data/repositories/delivery_address_repository.dart';
import 'package:dony/features/pickup_addresses/data/datasources/pickup_address_datasource.dart';
import 'package:dony/features/pickup_addresses/data/models/pickup_address.dart';
import 'package:dony/features/pickup_addresses/data/repositories/pickup_address_repository.dart';
import 'package:dony/features/recipients/data/datasources/recipient_datasource.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/data/repositories/recipient_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/recording_dio.dart';

const _pickupJson = {
  'id': 'p1',
  'label': 'Maison',
  'street': '1 rue de Paris',
  'postalCode': '75001',
  'city': 'Paris',
  'country': 'FR',
  'floorApartment': '3e gauche',
  'instructions': 'Code 1234',
  'latitude': 48,
  'longitude': 2.35,
  'isDefault': true,
};

const _deliveryJson = {
  'id': 'd1',
  'label': 'Chez maman',
  'street': 'Rue 10',
  'city': 'Dakar',
  'country': 'SN',
  'instructions': 'Sonner fort',
  'latitude': 14.7,
  'longitude': -17,
  'isDefault': false,
};

const _recipientJson = {
  'id': 'r1',
  'fullName': 'Awa Diop',
  'relationship': 'Sœur',
  'phoneE164': '+221770000000',
  'whatsappE164': '+221770000001',
  'street': 'Rue 10',
  'city': 'Dakar',
  'country': 'SN',
  'notes': 'Appeler avant',
  'isDefault': true,
  'linkedOnYadony': true,
};

void main() {
  late RecordingApi api;

  setUp(() => api = RecordingApi());

  group('PickupAddress', () {
    test('fromJson lit tous les champs et convertit les nombres', () {
      final a = PickupAddress.fromJson(_pickupJson);
      expect(a.id, 'p1');
      expect(a.label, 'Maison');
      expect(a.street, '1 rue de Paris');
      expect(a.postalCode, '75001');
      expect(a.city, 'Paris');
      expect(a.country, 'FR');
      expect(a.floorApartment, '3e gauche');
      expect(a.instructions, 'Code 1234');
      expect(a.latitude, 48.0);
      expect(a.longitude, 2.35);
      expect(a.isDefault, isTrue);
    });

    test('fromJson : isDefault absent vaut false, optionnels null', () {
      final a = PickupAddress.fromJson({
        'id': 'p2',
        'label': 'Bureau',
        'street': 's',
        'postalCode': '69001',
        'city': 'Lyon',
        'country': 'FR',
      });
      expect(a.isDefault, isFalse);
      expect(a.floorApartment, isNull);
      expect(a.latitude, isNull);
    });

    test('toJson omet les champs optionnels nuls', () {
      final full = PickupAddress.fromJson(_pickupJson).toJson();
      expect(full['floorApartment'], '3e gauche');
      expect(full['latitude'], 48.0);
      expect(full['isDefault'], isTrue);

      final minimal = const PickupAddress(
        id: 'p',
        label: 'l',
        street: 's',
        postalCode: 'c',
        city: 'v',
        country: 'FR',
        isDefault: false,
      ).toJson();
      expect(
        minimal.keys,
        containsAll(['id', 'label', 'street', 'postalCode', 'city']),
      );
      expect(minimal.containsKey('floorApartment'), isFalse);
      expect(minimal.containsKey('instructions'), isFalse);
      expect(minimal.containsKey('latitude'), isFalse);
      expect(minimal.containsKey('longitude'), isFalse);
    });

    test('copyWith remplace les champs fournis et garde les autres', () {
      final a = PickupAddress.fromJson(_pickupJson);
      final b = a.copyWith(
        label: 'Neuf',
        isDefault: false,
        latitude: 1,
        id: 'x',
        street: 'st',
        postalCode: 'pc',
        city: 'c',
        country: 'BE',
        floorApartment: 'f',
        instructions: 'i',
        longitude: 2,
      );
      expect(b.id, 'x');
      expect(b.label, 'Neuf');
      expect(b.isDefault, isFalse);
      expect(b.country, 'BE');
      expect(b.longitude, 2);
      final c = a.copyWith();
      expect(c.label, a.label);
      expect(c.instructions, a.instructions);
    });
  });

  group('PickupAddressDatasource / Repository', () {
    late PickupAddressRepository repo;

    setUp(() {
      repo = PickupAddressRepository(PickupAddressDatasource(api.client));
    });

    test('getAll lit la liste', () async {
      api.on('GET', '/addressbook/pickup-addresses', [_pickupJson]);
      final list = await repo.getAll();
      expect(list.single.id, 'p1');
      expect(api.last.method, 'GET');
    });

    test('create poste le corps', () async {
      api.on('POST', '/addressbook/pickup-addresses', _pickupJson);
      final a = await repo.create({'label': 'Maison'});
      expect(a.city, 'Paris');
      expect(api.last.data, {'label': 'Maison'});
    });

    test('update met à jour par id', () async {
      api.on('PUT', '/addressbook/pickup-addresses/p1', _pickupJson);
      await repo.update('p1', {'city': 'Paris'});
      expect(api.last.method, 'PUT');
      expect(api.last.data, {'city': 'Paris'});
    });

    test('setDefault appelle PATCH set-default', () async {
      api.on('PATCH', '/addressbook/pickup-addresses/p1/set-default', {
        ..._pickupJson,
        'isDefault': true,
      });
      final a = await repo.setDefault('p1');
      expect(a.isDefault, isTrue);
    });

    test('delete appelle DELETE', () async {
      await repo.delete('p1');
      expect(api.last.method, 'DELETE');
      expect(api.last.path, '/addressbook/pickup-addresses/p1');
    });

    test('une erreur HTTP remonte en DioException', () async {
      api.on('GET', '/addressbook/pickup-addresses', {
        'title': 'x',
      }, status: 500);
      await expectLater(repo.getAll(), throwsA(isA<DioException>()));
    });
  });

  group('DeliveryAddress', () {
    test('fromJson / toJson aller-retour', () {
      final a = DeliveryAddress.fromJson(_deliveryJson);
      expect(a.longitude, -17.0);
      expect(a.street, 'Rue 10');
      final json = a.toJson();
      expect(json['city'], 'Dakar');
      expect(json['instructions'], 'Sonner fort');
      expect(json['isDefault'], isFalse);
      expect(json['latitude'], 14.7);
    });

    test('toJson garde les clés nulles', () {
      const a = DeliveryAddress(
        id: 'd',
        label: 'l',
        city: 'Abidjan',
        country: 'CI',
        isDefault: true,
      );
      final json = a.toJson();
      expect(json.containsKey('street'), isTrue);
      expect(json['street'], isNull);
      expect(json['longitude'], isNull);
    });

    test('copyWith', () {
      final a = DeliveryAddress.fromJson(_deliveryJson);
      final b = a.copyWith(
        id: 'n',
        label: 'L',
        street: 'S',
        city: 'Bamako',
        country: 'ML',
        instructions: 'I',
        latitude: 1,
        longitude: 2,
        isDefault: true,
      );
      expect(b.city, 'Bamako');
      expect(b.isDefault, isTrue);
      expect(b.latitude, 1);
      expect(a.copyWith().label, 'Chez maman');
    });
  });

  group('DeliveryAddressDatasource / Repository', () {
    late DeliveryAddressRepository repo;

    setUp(() {
      repo = DeliveryAddressRepository(DeliveryAddressDatasource(api.client));
    });

    test('CRUD complet sur /addressbook/delivery-addresses', () async {
      api.on('GET', '/addressbook/delivery-addresses', [_deliveryJson]);
      api.on('POST', '/addressbook/delivery-addresses', _deliveryJson);
      api.on('PUT', '/addressbook/delivery-addresses/d1', _deliveryJson);
      api.on('PATCH', '/addressbook/delivery-addresses/d1/set-default', {
        ..._deliveryJson,
        'isDefault': true,
      });

      expect((await repo.getAll()).single.label, 'Chez maman');
      await repo.create({'label': 'x'});
      expect(api.last.data, {'label': 'x'});
      await repo.update('d1', {'label': 'y'});
      expect(api.last.method, 'PUT');
      expect((await repo.setDefault('d1')).isDefault, isTrue);
      await repo.delete('d1');

      expect(api.requests.map((r) => '${r.method} ${r.path}').toList(), [
        'GET /addressbook/delivery-addresses',
        'POST /addressbook/delivery-addresses',
        'PUT /addressbook/delivery-addresses/d1',
        'PATCH /addressbook/delivery-addresses/d1/set-default',
        'DELETE /addressbook/delivery-addresses/d1',
      ]);
    });
  });

  group('Recipient', () {
    test('fromJson lit tous les champs', () {
      final r = Recipient.fromJson(_recipientJson);
      expect(r.fullName, 'Awa Diop');
      expect(r.relationship, 'Sœur');
      expect(r.whatsappE164, '+221770000001');
      expect(r.notes, 'Appeler avant');
      expect(r.isDefault, isTrue);
      expect(r.linkedOnYadony, isTrue);
    });

    test('fromJson : back antérieur sans isDefault ni linkedOnYadony', () {
      final r = Recipient.fromJson({
        'id': 'r2',
        'fullName': 'Moussa',
        'phoneE164': '+2250700000000',
        'country': 'CI',
      });
      expect(r.isDefault, isFalse);
      expect(r.linkedOnYadony, isFalse);
      expect(r.city, isNull);
    });

    test('toJson omet les optionnels nuls et n’envoie pas linkedOnYadony', () {
      final full = Recipient.fromJson(_recipientJson).toJson();
      expect(full['relationship'], 'Sœur');
      expect(full['street'], 'Rue 10');
      expect(full.containsKey('linkedOnYadony'), isFalse);

      final minimal = const Recipient(
        id: 'r',
        fullName: 'n',
        phoneE164: '+33600000000',
        country: 'FR',
      ).toJson();
      expect(minimal.keys.toSet(), {
        'id',
        'fullName',
        'phoneE164',
        'country',
        'isDefault',
      });
    });

    test('copyWith ne change que isDefault', () {
      final r = Recipient.fromJson(_recipientJson);
      final c = r.copyWith(isDefault: false);
      expect(c.isDefault, isFalse);
      expect(c.linkedOnYadony, isTrue);
      expect(c.fullName, r.fullName);
      expect(r.copyWith().isDefault, isTrue);
    });
  });

  group('RecipientDatasource / Repository', () {
    test('CRUD complet sur /addressbook/recipients', () async {
      final repo = RecipientRepository(RecipientDatasource(api.client));
      api.on('GET', '/addressbook/recipients', [_recipientJson]);
      api.on('POST', '/addressbook/recipients', _recipientJson);
      api.on('PUT', '/addressbook/recipients/r1', _recipientJson);

      expect((await repo.getAll()).single.id, 'r1');
      final created = await repo.create({'fullName': 'Awa'});
      expect(created.phoneE164, '+221770000000');
      expect(api.last.data, {'fullName': 'Awa'});
      await repo.update('r1', {'notes': 'n'});
      expect(api.last.data, {'notes': 'n'});
      await repo.delete('r1');
      expect(api.last.method, 'DELETE');
      expect(api.last.path, '/addressbook/recipients/r1');
    });
  });
}
