import 'dart:io';

import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/services/saved_trips_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

late Directory _tempDir;
late HiveService _hiveService;
late SavedTripsService _service;

final _announcement = AnnouncementModel(
  id: 'ann-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2024, 6, 1),
  departureTime: '10:00',
  arrivalTime: '20:00',
  pickupAddress: const AddressData(label: 'CDG', lat: 49.0097, lng: 2.5479),
  deliveryAddress: const AddressData(label: 'DSS', lat: 14.7397, lng: -17.4902),
  availableKg: 10.0,
  totalKg: 10.0,
  pricePerKg: 12.0,
  status: 'OPEN',
  bidsCount: 0,
  createdAt: DateTime(2024, 5, 1),
  updatedAt: DateTime(2024, 5, 1),
);

Future<void> _setUp() async {
  _tempDir = await Directory.systemTemp.createTemp('saved_trips_test_');
  Hive.init(_tempDir.path);
  await Hive.openBox<Map>(HiveService.offlineQueueBox);
  await Hive.openBox(HiveService.userPrefsBox);
  _hiveService = HiveService();
  _service = SavedTripsService(_hiveService);
}

Future<void> _tearDown() async {
  await Hive.close();
  await _tempDir.delete(recursive: true);
}

void main() {
  setUpAll(() async => _setUp());
  tearDownAll(() async => _tearDown());

  setUp(() async {
    await _hiveService.userPrefs.clear();
  });

  group('SavedTripsService', () {
    test('getSavedTrips returns empty list when nothing saved', () {
      expect(_service.getSavedTrips(), isEmpty);
    });

    test('isSaved returns false for unknown id', () {
      expect(_service.isSaved('unknown'), isFalse);
    });

    test('saveTrip adds announcement and isSaved returns true', () async {
      await _service.saveTrip(_announcement);
      expect(_service.isSaved('ann-1'), isTrue);
      expect(_service.getSavedTrips(), hasLength(1));
    });

    test('saveTrip does not add duplicates', () async {
      await _service.saveTrip(_announcement);
      await _service.saveTrip(_announcement);
      expect(_service.getSavedTrips(), hasLength(1));
    });

    test('removeTrip removes the announcement', () async {
      await _service.saveTrip(_announcement);
      await _service.removeTrip('ann-1');
      expect(_service.isSaved('ann-1'), isFalse);
      expect(_service.getSavedTrips(), isEmpty);
    });

    test('removeTrip with unknown id leaves list unchanged', () async {
      await _service.saveTrip(_announcement);
      await _service.removeTrip('does-not-exist');
      expect(_service.getSavedTrips(), hasLength(1));
    });

    test('getSavedTrips returns empty on corrupt data', () async {
      await _hiveService.userPrefs.put('saved_trips', 'NOT_VALID_JSON');
      expect(_service.getSavedTrips(), isEmpty);
    });

    test('getSavedTrips persists traveler profile when not null', () async {
      final withTraveler = AnnouncementModel(
        id: 'ann-2',
        travelerId: 'trav-2',
        departureCity: 'Lyon',
        arrivalCity: 'Abidjan',
        departureDate: DateTime(2024, 7, 1),
        availableKg: 5.0,
        totalKg: 5.0,
        pricePerKg: 15.0,
        status: 'OPEN',
        bidsCount: 0,
        createdAt: DateTime(2024, 5, 1),
        updatedAt: DateTime(2024, 5, 1),
        traveler: const TravelerProfile(
          id: 'tp-1',
          displayName: 'Ibrahima Diallo',
          kiloPro: false,
        ),
      );
      await _service.saveTrip(withTraveler);
      final saved = _service.getSavedTrips();
      expect(saved.first.traveler?.displayName, 'Ibrahima Diallo');
    });

    test('getSavedTrips preserves acceptedPaymentMethods (le cash n\'est pas perdu)',
        () async {
      // Régression : l'ancien _toMap omettait acceptedPaymentMethods → un trajet
      // rouvert depuis les favoris retombait sur {stripe} et ne proposait plus le cash.
      final withCash = AnnouncementModel(
        id: 'ann-cash',
        travelerId: 'trav-3',
        departureCity: 'Marseille',
        arrivalCity: 'Bamako',
        departureDate: DateTime(2024, 8, 1),
        availableKg: 8.0,
        totalKg: 8.0,
        pricePerKg: 10.0,
        status: 'OPEN',
        bidsCount: 0,
        createdAt: DateTime(2024, 5, 1),
        updatedAt: DateTime(2024, 5, 1),
        acceptedPaymentMethods: const {
          BidPaymentMethod.stripe,
          BidPaymentMethod.cash,
        },
      );
      await _service.saveTrip(withCash);
      final saved = _service.getSavedTrips();
      expect(
        saved.first.acceptedPaymentMethods,
        containsAll(<BidPaymentMethod>[
          BidPaymentMethod.stripe,
          BidPaymentMethod.cash,
        ]),
      );
    });
  });
}
