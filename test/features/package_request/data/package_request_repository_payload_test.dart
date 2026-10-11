import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/recording_dio.dart';

const _prJson = <String, dynamic>{
  'id': 'pr-1',
  'senderId': 'sender-1',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'desiredDate': '2026-06-15',
  'dateToleranceDays': 2,
  'weightKg': 5.0,
  'parcelSize': 'SMALL',
  'contentCategory': 'vetements',
  'status': 'OPEN',
  'createdAt': '2026-05-10T10:00:00Z',
};

const _threadJson = <String, dynamic>{
  'id': 'th-1',
  'packageRequestId': 'pr-1',
  'travelerId': 'trav-1',
  'travelerTravelDate': '2026-06-14T00:00:00Z',
  'travelerAvailableKg': 10,
  'status': 'OPEN',
  'currentPriceEur': 40,
  'roundsCount': 1,
  'lastActivityAt': '2026-05-11T10:00:00Z',
  'createdAt': '2026-05-11T09:00:00Z',
};

void main() {
  late RecordingApi api;
  late PackageRequestRepository repo;

  setUp(() {
    api = RecordingApi();
    repo = PackageRequestRepository(api.client);
  });

  group('create / update : champs optionnels', () {
    test('create envoie tous les optionnels renseignés', () async {
      api.on('POST', '/package-requests', _prJson);

      await repo.create(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        desiredDate: DateTime(2026, 6, 15),
        dateToleranceDays: 2,
        weightKg: 5,
        parcelSize: ParcelSize.medium,
        transportMode: TransportMode.plane,
        categories: const ['CLOTHING', 'FOOD'],
        negotiable: false,
        acceptedPaymentMethods: {PaymentMethod.stripe, PaymentMethod.cash},
        totalBudgetEur: 60,
        description: 'Vêtements',
        photoUrl: 'https://cdn/p.jpg',
        pickupNeighborhood: 'Belleville',
        deliveryNeighborhood: 'Plateau',
        photoKeys: const ['k1'],
        promoCode: 'PROMO',
        currency: 'XOF',
      );

      final body = api.last.data as Map<String, dynamic>;
      expect(body['desiredDate'], '2026-06-15');
      expect(body['parcelSize'], 'MEDIUM');
      expect(body['transportMode'], 'PLANE');
      expect(body['contentCategory'], 'CLOTHING,FOOD');
      expect(body['acceptedPaymentMethods'], ['STRIPE', 'CASH']);
      expect(body['totalBudgetEur'], 60);
      expect(body['description'], 'Vêtements');
      expect(body['photoUrl'], 'https://cdn/p.jpg');
      expect(body['pickupNeighborhood'], 'Belleville');
      expect(body['deliveryNeighborhood'], 'Plateau');
      expect(body['photoKeys'], ['k1']);
      expect(body['promoCode'], 'PROMO');
      expect(body['currency'], 'XOF');
      expect(body['saveAsDraft'], isFalse);
    });

    test('update envoie les optionnels et omet ceux absents', () async {
      api.on('PUT', '/package-requests/pr-1', _prJson);

      final updated = await repo.update(
        'pr-1',
        departureCity: 'Lyon',
        arrivalCity: 'Abidjan',
        desiredDate: DateTime(2026, 7),
        dateToleranceDays: 0,
        weightKg: 3,
        parcelSize: ParcelSize.large,
        transportMode: TransportMode.boat,
        categories: const ['DOCS'],
        negotiable: true,
        acceptedPaymentMethods: {PaymentMethod.wave},
        totalBudgetEur: 30,
        description: 'Papiers',
        photoUrl: 'u',
        pickupNeighborhood: 'Part-Dieu',
        deliveryNeighborhood: 'Cocody',
      );

      expect(updated.id, 'pr-1');
      final body = api.last.data as Map<String, dynamic>;
      expect(body['departureCity'], 'Lyon');
      expect(body['desiredDate'], '2026-07-01');
      expect(body['parcelSize'], 'LARGE');
      expect(body['acceptedPaymentMethods'], ['WAVE']);
      expect(body['totalBudgetEur'], 30);
      expect(body['description'], 'Papiers');
      expect(body['photoUrl'], 'u');
      expect(body['pickupNeighborhood'], 'Part-Dieu');
      expect(body['deliveryNeighborhood'], 'Cocody');
      expect(body.containsKey('photoKeys'), isFalse);
      expect(body.containsKey('promoCode'), isFalse);
    });
  });

  group('uploadPhoto', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('pr_photo'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('envoie un multipart JPEG et rend l’URL', () async {
      final file = File('${dir.path}/p.jpg')..writeAsBytesSync([1, 2, 3]);
      api.on('POST', '/storage/upload/package-request', {
        'url': 'https://cdn/photo.jpg',
      });

      final url = await repo.uploadPhoto(file);

      expect(url, 'https://cdn/photo.jpg');
      final form = api.last.data as FormData;
      final part = form.files.single;
      expect(part.key, 'file');
      expect(part.value.filename, endsWith('_photo.jpg'));
      expect(part.value.contentType.toString(), 'image/jpeg');
      expect(part.value.length, 3);
    });
  });

  group('listThreadsForRequest', () {
    test('lit les fils de négociation', () async {
      api.on('GET', '/package-requests/pr-1/threads', [_threadJson]);
      final threads = await repo.listThreadsForRequest('pr-1');
      expect(threads.single.id, 'th-1');
      expect(threads.single.status, NegotiationThreadStatus.open);
      expect(threads.single.currentPriceEur, 40.0);
    });

    test('rend une liste vide sur une réponse sans corps', () async {
      api.on('GET', '/package-requests/pr-1/threads', null);
      expect(await repo.listThreadsForRequest('pr-1'), isEmpty);
    });
  });

  group('alerte de match colis', () {
    test('getPackageMatchAlert lit enabled', () async {
      api.on('GET', '/notifications/package-match-alert', {'enabled': false});
      expect(await repo.getPackageMatchAlert(), isFalse);
    });

    test('getPackageMatchAlert vaut true par défaut', () async {
      api.on('GET', '/notifications/package-match-alert', <String, dynamic>{});
      expect(await repo.getPackageMatchAlert(), isTrue);
    });

    test('setPackageMatchAlert envoie un PUT', () async {
      await repo.setPackageMatchAlert(false);
      expect(api.last.method, 'PUT');
      expect(api.last.path, '/notifications/package-match-alert');
      expect(api.last.data, {'enabled': false});
    });
  });

  group('search', () {
    test('envoie tous les filtres renseignés en query', () async {
      api.on('GET', '/package-requests', {
        'content': <dynamic>[],
        'totalElements': 0,
      });

      final page = await repo.search(
        departure: 'Paris',
        arrival: 'Dakar',
        dateFrom: DateTime(2026, 6),
        dateTo: DateTime(2026, 6, 30),
        maxWeight: 10,
        parcelSize: ParcelSize.small,
        lat: 48.8,
        lng: 2.3,
        radiusKm: 25,
        page: 1,
        size: 10,
        urgent: true,
        matchingMyTrips: true,
      );

      expect(page.content, isEmpty);
      expect(page.size, 20);
      expect(api.last.queryParameters, {
        'page': 1,
        'size': 10,
        'departure': 'Paris',
        'arrival': 'Dakar',
        'dateFrom': '2026-06-01',
        'dateTo': '2026-06-30',
        'maxWeight': 10.0,
        'parcelSize': 'SMALL',
        'lat': 48.8,
        'lng': 2.3,
        'radiusKm': 25.0,
        'urgent': true,
        'matchingMyTrips': true,
      });
    });

    test('n’envoie jamais urgent ni matchingMyTrips à false', () async {
      api.on('GET', '/package-requests', {'content': <dynamic>[]});
      await repo.search(urgent: false, matchingMyTrips: false);
      expect(api.last.queryParameters, {'page': 0, 'size': 20});
    });
  });
}
