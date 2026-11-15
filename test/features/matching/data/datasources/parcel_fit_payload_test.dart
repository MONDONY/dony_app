import 'package:dony/features/matching/data/datasources/announcement_remote_datasource.dart';
import 'package:dony/features/matching/data/datasources/bid_remote_datasource.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_payload.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/parcel_fit_wire.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/recording_dio.dart';

const _announcementJson = {
  'id': 'ann-001',
  'travelerId': 'trav-001',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': '2024-06-01T00:00:00.000Z',
  'availableKg': 1200.0,
  'totalKg': 1200.0,
  'pricePerKg': 12.0,
  'status': 'ACTIVE',
  'createdAt': '2024-05-01T00:00:00.000Z',
  'updatedAt': '2024-05-01T00:00:00.000Z',
};

const _bidJson = {
  'id': 'bid-001',
  'announcementId': 'ann-001',
  'senderId': 'sender-001',
  'weightKg': 5.0,
  'status': 'PENDING',
  'createdAt': '2024-05-01T00:00:00.000Z',
  'updatedAt': '2024-05-01T00:00:00.000Z',
};

const _pickup = AddressData(label: 'Gare', lat: 48.8, lng: 2.3);
const _delivery = AddressData(label: 'Gare routière', lat: 14.7, lng: -17.4);

void main() {
  late RecordingApi api;
  late AnnouncementRepository announcements;

  setUp(() {
    api = RecordingApi();
    announcements = AnnouncementRepository(
      AnnouncementRemoteDatasource(api.client),
    );
  });

  Future<void> create({ItemSize? size, double? weight}) {
    api.on('POST', '/announcements', _announcementJson, status: 201);
    return announcements.createAnnouncement(
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 12),
      pickupAddress: _pickup,
      deliveryAddress: _delivery,
      availableKg: 1200,
      pricePerKg: 3,
      transportMode: TransportMode.car,
      handoverDeadline: DateTime.utc(2026, 11, 30),
      maxItemSize: size,
      maxParcelWeightKg: weight,
    );
  }

  Future<void> update({
    FieldChange<ItemSize> size = const FieldChange.keep(),
    FieldChange<double> weight = const FieldChange.keep(),
  }) {
    api.on('PUT', '/announcements/ann-001', _announcementJson);
    return announcements.updateAnnouncement(
      id: 'ann-001',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 12),
      pickupAddress: _pickup,
      deliveryAddress: _delivery,
      availableKg: 1200,
      pricePerKg: 3,
      transportMode: TransportMode.car,
      handoverDeadline: DateTime.utc(2026, 11, 30),
      maxItemSize: size,
      maxParcelWeightKg: weight,
    );
  }

  Map<String, dynamic> body() => api.last.data as Map<String, dynamic>;

  group('création de trajet', () {
    test('taille et poids max renseignés : envoyés', () async {
      await create(size: ItemSize.l, weight: 20.5);
      expect(body()['maxItemSize'], 'L');
      expect(body()['maxParcelWeightKg'], 20.5);
      expect(body()['availableKg'], 1200);
    });

    test('non renseignés : aucune des deux clés', () async {
      await create();
      expect(body().containsKey('maxItemSize'), isFalse);
      expect(body().containsKey('maxParcelWeightKg'), isFalse);
    });

    test('poids à 999 999,99 sans perte', () async {
      await create(weight: 999999.99);
      expect(body()['maxParcelWeightKg'], 999999.99);
    });
  });

  group('modification de trajet : inchangé, renseigné, effacé', () {
    test('inchangé : aucune des deux clés (le back conserve)', () async {
      await update();
      expect(body().containsKey('maxItemSize'), isFalse);
      expect(body().containsKey('maxParcelWeightKg'), isFalse);
    });

    test('renseigné : le code et le poids', () async {
      await update(
        size: const FieldChange.set(ItemSize.xl),
        weight: const FieldChange.set(15),
      );
      expect(body()['maxItemSize'], 'XL');
      expect(body()['maxParcelWeightKg'], 15);
    });

    test('effacé : NONE et 0', () async {
      await update(
        size: const FieldChange.clear(),
        weight: const FieldChange.clear(),
      );
      expect(body()['maxItemSize'], 'NONE');
      expect(body()['maxParcelWeightKg'], 0);
    });

    test('un seul des deux effacé : l\'autre reste absent', () async {
      await update(size: const FieldChange.clear());
      expect(body()['maxItemSize'], 'NONE');
      expect(body().containsKey('maxParcelWeightKg'), isFalse);
    });
  });

  group('AnnouncementPayload (étape d\'un voyage)', () {
    AnnouncementPayload payload({ItemSize? size, double? weight}) =>
        AnnouncementPayload(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime(2026, 12),
          pickupAddress: _pickup,
          deliveryAddress: _delivery,
          availableKg: 1200,
          pricePerKg: 3,
          transportMode: TransportMode.car,
          handoverDeadline: DateTime.utc(2026, 11, 30),
          maxItemSize: size,
          maxParcelWeightKg: weight,
        );

    test('clés absentes quand non renseignées', () {
      final json = payload().toJson();
      expect(json.containsKey('maxItemSize'), isFalse);
      expect(json.containsKey('maxParcelWeightKg'), isFalse);
    });

    test('clés présentes quand renseignées, et prises en compte par ==', () {
      final json = payload(size: ItemSize.m, weight: 8).toJson();
      expect(json['maxItemSize'], 'M');
      expect(json['maxParcelWeightKg'], 8);
      expect(payload(size: ItemSize.m), isNot(payload(size: ItemSize.l)));
    });
  });

  group('réservation', () {
    late BidRepository bids;

    setUp(() => bids = BidRepository(BidRemoteDatasource(api.client)));

    Future<void> createBid({ItemSize? size}) {
      api.on('POST', '/announcements/ann-001/bids', _bidJson, status: 201);
      return bids.createBid(
        announcementId: 'ann-001',
        weightKg: 5,
        description: 'd',
        contentCategory: 'CLOTHING',
        recipientName: 'Awa',
        recipientPhone: '+221',
        itemSize: size,
      );
    }

    Future<void> checkout({ItemSize? size}) {
      api.on('POST', '/bids/checkout', {
        'bidId': 'bid-001',
        'clientSecret': 'pi_secret',
        'publishableKey': 'pk',
        'expiresAt': '2026-06-01T10:00:00Z',
      });
      return bids.checkoutBid(
        announcementId: 'ann-001',
        weightKg: 5,
        description: 'd',
        contentCategory: 'CLOTHING',
        recipientName: 'Awa',
        recipientPhone: '+221',
        itemSize: size,
      );
    }

    test('createBid envoie itemSize quand renseignée', () async {
      await createBid(size: ItemSize.m);
      expect(body()['itemSize'], 'M');
    });

    test('createBid sans taille : clé absente', () async {
      await createBid();
      expect(body().containsKey('itemSize'), isFalse);
    });

    test('checkoutBid envoie itemSize quand renseignée', () async {
      await checkout(size: ItemSize.xl);
      expect(body()['itemSize'], 'XL');
    });

    test('checkoutBid sans taille : clé absente', () async {
      await checkout();
      expect(body().containsKey('itemSize'), isFalse);
    });
  });

  group('trajet bateau (lot 3)', () {
    test(
      'création au m³ : volume, prix au m³, fourchette, aucun kilo',
      () async {
        api.on('POST', '/announcements', _announcementJson, status: 201);
        await announcements.createAnnouncement(
          departureCity: 'Marseille',
          arrivalCity: 'Dakar',
          departureDate: DateTime(2026, 12),
          arrivalDate: '2027-01-10',
          pickupAddress: _pickup,
          deliveryAddress: _delivery,
          availableKg: null,
          pricePerKg: null,
          transportMode: TransportMode.boat,
          arrivalDateMax: '2027-01-25',
          volumeCapacityM3: 12.5,
          pricePerM3: 150,
          handoverDeadline: DateTime.utc(2026, 11, 30),
          maxParcelWeightKg: 40,
        );
        expect(body()['transportMode'], 'BOAT');
        expect(body().containsKey('availableKg'), isFalse);
        expect(body().containsKey('pricePerKg'), isFalse);
        expect(body()['arrivalDate'], '2027-01-10');
        expect(body()['arrivalDateMax'], '2027-01-25');
        expect(body()['volumeCapacityM3'], 12.5);
        expect(body()['pricePerM3'], 150);
        expect(body()['maxParcelWeightKg'], 40);
      },
    );

    test(
      'modification au m³ : aucun kilo, poids max inchangé absent',
      () async {
        api.on('PUT', '/announcements/ann-001', _announcementJson);
        await announcements.updateAnnouncement(
          id: 'ann-001',
          departureCity: 'Marseille',
          arrivalCity: 'Dakar',
          departureDate: DateTime(2026, 12),
          arrivalDate: '2027-01-10',
          pickupAddress: _pickup,
          deliveryAddress: _delivery,
          availableKg: null,
          pricePerKg: null,
          transportMode: TransportMode.boat,
          arrivalDateMax: '2027-01-25',
          volumeCapacityM3: 20,
          pricePerM3: 120,
          handoverDeadline: DateTime.utc(2026, 11, 30),
        );
        expect(body().containsKey('availableKg'), isFalse);
        expect(body().containsKey('pricePerKg'), isFalse);
        expect(body()['arrivalDateMax'], '2027-01-25');
        expect(body()['volumeCapacityM3'], 20);
        expect(body()['pricePerM3'], 120);
        expect(body().containsKey('maxParcelWeightKg'), isFalse);
      },
    );

    test('hors bateau : aucun champ bateau dans le corps', () async {
      await create();
      expect(body().containsKey('arrivalDateMax'), isFalse);
      expect(body().containsKey('volumeCapacityM3'), isFalse);
      expect(body().containsKey('pricePerM3'), isFalse);
      expect(body()['pricePerKg'], 3);
    });

    test('AnnouncementPayload au m³ : sans kilos', () {
      final json = AnnouncementPayload(
        departureCity: 'Marseille',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2026, 12),
        pickupAddress: _pickup,
        deliveryAddress: _delivery,
        availableKg: null,
        pricePerKg: null,
        transportMode: TransportMode.boat,
        arrivalDateMax: '2027-01-25',
        volumeCapacityM3: 3,
        pricePerM3: 99,
        handoverDeadline: DateTime.utc(2026, 11, 30),
      ).toJson();
      expect(json.containsKey('availableKg'), isFalse);
      expect(json.containsKey('pricePerKg'), isFalse);
      expect(json['volumeCapacityM3'], 3);
      expect(json['pricePerM3'], 99);
      expect(json['arrivalDateMax'], '2027-01-25');
    });
  });
}
