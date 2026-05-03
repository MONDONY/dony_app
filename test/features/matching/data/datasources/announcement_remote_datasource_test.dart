import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/datasources/announcement_remote_datasource.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

final _announcementJson = {
  'id': 'ann-001',
  'travelerId': 'trav-001',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': '2024-06-01T00:00:00.000Z',
  'availableKg': 10.0,
  'totalKg': 10.0,
  'pricePerKg': 12.0,
  'status': 'OPEN',
  'createdAt': '2024-05-01T00:00:00.000Z',
  'updatedAt': '2024-05-01T00:00:00.000Z',
};

Response<dynamic> _ok(dynamic data, String path) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );

const kPickup = AddressData(label: 'CDG Terminal 2', lat: 49.0097, lng: 2.5479);
const kDelivery = AddressData(label: 'Aéroport LSS', lat: 14.7397, lng: -17.4902);

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late AnnouncementRemoteDatasource datasource;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    datasource = AnnouncementRemoteDatasource(mockClient);
  });

  // ── createAnnouncement ───────────────────────────────────────────────────────

  group('createAnnouncement', () {
    test('returns AnnouncementModel on success', () async {
      when(() => mockDio.post('/announcements', data: any(named: 'data')))
          .thenAnswer((_) async => _ok(_announcementJson, '/announcements'));

      final result = await datasource.createAnnouncement(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2024, 6, 1),
        pickupAddress: kPickup,
        deliveryAddress: kDelivery,
        availableKg: 10.0,
        pricePerKg: 12.0,
        transportMode: TransportMode.plane,
      );

      expect(result.id, 'ann-001');
      expect(result.departureCity, 'Paris');
    });

    test('includes optional time/address fields when provided', () async {
      when(() => mockDio.post('/announcements', data: any(named: 'data')))
          .thenAnswer((_) async => _ok(_announcementJson, '/announcements'));

      final result = await datasource.createAnnouncement(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2024, 6, 1),
        departureTime: '10:00',
        arrivalTime: '20:00',
        pickupAddress: kPickup,
        deliveryAddress: kDelivery,
        availableKg: 10.0,
        pricePerKg: 12.0,
        transportMode: TransportMode.plane,
      );

      expect(result.id, 'ann-001');
    });

    test('sends transportMode wire value in payload', () async {
      Map<String, dynamic>? capturedData;
      when(() => mockDio.post('/announcements', data: any(named: 'data')))
          .thenAnswer((inv) async {
        capturedData = inv.namedArguments[const Symbol('data')]
            as Map<String, dynamic>;
        return _ok(_announcementJson, '/announcements');
      });

      await datasource.createAnnouncement(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2024, 6, 1),
        pickupAddress: kPickup,
        deliveryAddress: kDelivery,
        availableKg: 10.0,
        pricePerKg: 12.0,
        transportMode: TransportMode.train,
      );

      expect(capturedData, isNotNull);
      expect(capturedData!['transportMode'], 'TRAIN');
    });
  });

  // ── getMyAnnouncements ───────────────────────────────────────────────────────

  group('getMyAnnouncements', () {
    test('returns list and totalElements', () async {
      when(() => mockDio.get('/announcements/my',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({
                'content': [_announcementJson],
                'totalElements': 1,
              }, '/announcements/my'));

      final result = await datasource.getMyAnnouncements();

      expect(result.announcements, hasLength(1));
      expect(result.totalElements, 1);
    });

    test('falls back to list length when totalElements missing', () async {
      when(() => mockDio.get('/announcements/my',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({
                'content': [_announcementJson, _announcementJson],
              }, '/announcements/my'));

      final result = await datasource.getMyAnnouncements(page: 1);

      expect(result.totalElements, 2);
    });
  });

  // ── getAnnouncementDetail ────────────────────────────────────────────────────

  group('getAnnouncementDetail', () {
    test('returns AnnouncementModel by id', () async {
      when(() => mockDio.get('/announcements/ann-001'))
          .thenAnswer((_) async => _ok(_announcementJson, '/announcements/ann-001'));

      final result = await datasource.getAnnouncementDetail('ann-001');

      expect(result.id, 'ann-001');
    });
  });

  // ── searchAnnouncements ──────────────────────────────────────────────────────

  group('searchAnnouncements', () {
    test('returns list of announcements', () async {
      when(() => mockDio.get('/announcements',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({
                'content': [_announcementJson],
              }, '/announcements'));

      final results = await datasource.searchAnnouncements(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
      );

      expect(results, hasLength(1));
    });

    test('uses optional date filters when provided', () async {
      when(() => mockDio.get('/announcements',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'content': []}, '/announcements'));

      final results = await datasource.searchAnnouncements(
        departureDateFrom: DateTime(2024, 6, 1),
        departureDateTo: DateTime(2024, 6, 30),
        minAvailableKg: 5.0,
      );

      expect(results, isEmpty);
    });
  });

  // ── deleteAnnouncement ───────────────────────────────────────────────────────

  group('deleteAnnouncement', () {
    test('calls DELETE and completes', () async {
      when(() => mockDio.delete('/announcements/ann-001'))
          .thenAnswer((_) async => _ok(null, '/announcements/ann-001'));

      await expectLater(
          datasource.deleteAnnouncement('ann-001'), completes);
    });
  });

  // ── updateAnnouncement ───────────────────────────────────────────────────────

  group('updateAnnouncement', () {
    test('returns updated AnnouncementModel', () async {
      when(() => mockDio.put('/announcements/ann-001',
              data: any(named: 'data')))
          .thenAnswer((_) async => _ok(_announcementJson, '/announcements/ann-001'));

      final result = await datasource.updateAnnouncement(
        id: 'ann-001',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2024, 6, 1),
        pickupAddress: kPickup,
        deliveryAddress: kDelivery,
        availableKg: 10.0,
        pricePerKg: 12.0,
        transportMode: TransportMode.plane,
      );

      expect(result.id, 'ann-001');
    });

    test('with optional time and address fields', () async {
      when(() => mockDio.put('/announcements/ann-001',
              data: any(named: 'data')))
          .thenAnswer((_) async => _ok(_announcementJson, '/announcements/ann-001'));

      final result = await datasource.updateAnnouncement(
        id: 'ann-001',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2024, 6, 1),
        departureTime: '08:00',
        arrivalTime: '20:00',
        pickupAddress: kPickup,
        deliveryAddress: kDelivery,
        availableKg: 10.0,
        pricePerKg: 12.0,
        transportMode: TransportMode.plane,
      );

      expect(result.id, 'ann-001');
    });

    test('sends transportMode wire value in payload', () async {
      Map<String, dynamic>? capturedData;
      when(() => mockDio.put('/announcements/ann-001',
              data: any(named: 'data')))
          .thenAnswer((inv) async {
        capturedData = inv.namedArguments[const Symbol('data')]
            as Map<String, dynamic>;
        return _ok(_announcementJson, '/announcements/ann-001');
      });

      await datasource.updateAnnouncement(
        id: 'ann-001',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2024, 6, 1),
        pickupAddress: kPickup,
        deliveryAddress: kDelivery,
        availableKg: 10.0,
        pricePerKg: 12.0,
        transportMode: TransportMode.boat,
      );

      expect(capturedData, isNotNull);
      expect(capturedData!['transportMode'], 'BOAT');
    });
  });
}
