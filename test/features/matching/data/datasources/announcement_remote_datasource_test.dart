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
        handoverWindowStart: DateTime(2026, 6, 14, 16),
        handoverWindowEnd: DateTime(2026, 6, 14, 18),
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
        handoverWindowStart: DateTime(2026, 6, 14, 16),
        handoverWindowEnd: DateTime(2026, 6, 14, 18),
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
        handoverWindowStart: DateTime(2026, 6, 14, 16),
        handoverWindowEnd: DateTime(2026, 6, 14, 18),
      );

      expect(capturedData, isNotNull);
      expect(capturedData!['transportMode'], 'TRAIN');
    });

    test('includes country codes in payload when provided', () async {
      Map<String, dynamic>? capturedData;
      when(() => mockDio.post('/announcements', data: any(named: 'data')))
          .thenAnswer((inv) async {
        capturedData = inv.namedArguments[const Symbol('data')]
            as Map<String, dynamic>;
        return _ok(_announcementJson, '/announcements');
      });

      await datasource.createAnnouncement(
        departureCity: 'New York',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2024, 6, 1),
        pickupAddress: kPickup,
        deliveryAddress: kDelivery,
        availableKg: 10.0,
        pricePerKg: 12.0,
        transportMode: TransportMode.plane,
        departureCountryCode: 'US',
        arrivalCountryCode: 'SN',
        handoverWindowStart: DateTime(2026, 6, 14, 16),
        handoverWindowEnd: DateTime(2026, 6, 14, 18),
      );

      expect(capturedData, isNotNull);
      expect(capturedData!['departureCountryCode'], 'US');
      expect(capturedData!['arrivalCountryCode'], 'SN');
    });

    test('omits country code keys when null', () async {
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
        transportMode: TransportMode.plane,
        handoverWindowStart: DateTime(2026, 6, 14, 16),
        handoverWindowEnd: DateTime(2026, 6, 14, 18),
      );

      expect(capturedData, isNotNull);
      expect(capturedData!.containsKey('departureCountryCode'), isFalse);
      expect(capturedData!.containsKey('arrivalCountryCode'), isFalse);
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

      final result = await datasource.getMyAnnouncements();

      expect(result.totalElements, 2);
    });

    test('charge toutes les pages quand le total dépasse une page', () async {
      when(() => mockDio.get('/announcements/my',
              queryParameters: {'page': 0, 'size': 50}))
          .thenAnswer((_) async => _ok({
                'content': List.generate(50, (_) => _announcementJson),
                'totalElements': 75,
              }, '/announcements/my'));
      when(() => mockDio.get('/announcements/my',
              queryParameters: {'page': 1, 'size': 50}))
          .thenAnswer((_) async => _ok({
                'content': List.generate(25, (_) => _announcementJson),
                'totalElements': 75,
              }, '/announcements/my'));

      final result = await datasource.getMyAnnouncements();

      expect(result.announcements, hasLength(75));
      expect(result.totalElements, 75);
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

    test('sends urgent=true when urgent: true', () async {
      when(() => mockDio.get('/announcements',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'content': []}, '/announcements'));

      await datasource.searchAnnouncements(urgent: true);

      final captured = verify(() => mockDio.get('/announcements',
              queryParameters: captureAny(named: 'queryParameters')))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['urgent'], true);
    });

    test('omits urgent param when urgent is false or null (never sends urgent=false)',
        () async {
      when(() => mockDio.get('/announcements',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'content': []}, '/announcements'));

      await datasource.searchAnnouncements(urgent: false);
      await datasource.searchAnnouncements();

      final calls = verify(() => mockDio.get('/announcements',
              queryParameters: captureAny(named: 'queryParameters')))
          .captured;
      for (final c in calls) {
        expect((c as Map<String, dynamic>).containsKey('urgent'), isFalse);
      }
    });
  });

  // ── countAnnouncements ───────────────────────────────────────────────────────

  group('countAnnouncements', () {
    void stubCount(Map<String, dynamic> body) {
      when(() => mockDio.get<Map<String, dynamic>>('/announcements',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response<Map<String, dynamic>>(
                data: body,
                statusCode: 200,
                requestOptions: RequestOptions(path: '/announcements'),
              ));
    }

    Map<String, dynamic> capturedQuery() =>
        verify(() => mockDio.get<Map<String, dynamic>>('/announcements',
                queryParameters: captureAny(named: 'queryParameters')))
            .captured
            .single as Map<String, dynamic>;

    test('tape GET /announcements avec une page de taille 1', () async {
      stubCount({'content': <dynamic>[], 'totalElements': 42});

      await datasource.countAnnouncements(departureCity: 'Paris');

      final q = capturedQuery();
      expect(q['page'], 0);
      expect(q['size'], 1);
      expect(q['departureCity'], 'Paris');
    });

    test('renvoie totalElements et non la taille du content', () async {
      stubCount({'content': <dynamic>[_announcementJson], 'totalElements': 42});

      final total = await datasource.countAnnouncements();

      expect(total, 42);
    });

    test('renvoie 0 quand totalElements est absent', () async {
      stubCount({'content': <dynamic>[]});

      expect(await datasource.countAnnouncements(), 0);
    });

    test('formate les dates en yyyy-MM-dd', () async {
      stubCount({'totalElements': 0});

      await datasource.countAnnouncements(
        departureDateFrom: DateTime(2026, 1, 5),
        departureDateTo: DateTime(2026, 2, 28),
      );

      final q = capturedQuery();
      expect(q['departureDateFrom'], '2026-01-05');
      expect(q['departureDateTo'], '2026-02-28');
    });

    test('transmet la position et le rayon de « près de moi »', () async {
      stubCount({'totalElements': 3});

      await datasource.countAnnouncements(
        userLat: 48.8566,
        userLng: 2.3522,
        radiusKm: 25,
      );

      final q = capturedQuery();
      expect(q['userLat'], 48.8566);
      expect(q['userLng'], 2.3522);
      expect(q['radiusKm'], 25);
    });

    test('n\'envoie jamais urgent=false', () async {
      stubCount({'totalElements': 0});

      await datasource.countAnnouncements(urgent: false);

      expect(capturedQuery().containsKey('urgent'), isFalse);
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

  // ── openSurplus ──────────────────────────────────────────────────────────────

  group('openSurplus', () {
    test('POSTs to /negotiations/trip/{id}/open-surplus then reloads detail',
        () async {
      when(() => mockDio.post(
                '/negotiations/trip/ann-001/open-surplus',
                data: any(named: 'data'),
              ))
          .thenAnswer((_) async =>
              _ok(null, '/negotiations/trip/ann-001/open-surplus'));
      when(() => mockDio.get('/announcements/ann-001')).thenAnswer(
          (_) async => _ok(_announcementJson, '/announcements/ann-001'));

      final result = await datasource.openSurplus(
        announcementId: 'ann-001',
        surplusKg: 8.0,
        pricePerKg: 7.0,
      );

      expect(result.id, 'ann-001');
      final captured = verify(() => mockDio.post(
            '/negotiations/trip/ann-001/open-surplus',
            data: captureAny(named: 'data'),
          )).captured.single as Map<String, dynamic>;
      expect(captured['surplusKg'], 8.0);
      expect(captured['pricePerKg'], 7.0);
      verify(() => mockDio.get('/announcements/ann-001')).called(1);
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
        handoverWindowStart: DateTime(2026, 6, 14, 16),
        handoverWindowEnd: DateTime(2026, 6, 14, 18),
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
        handoverWindowStart: DateTime(2026, 6, 14, 16),
        handoverWindowEnd: DateTime(2026, 6, 14, 18),
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
        handoverWindowStart: DateTime(2026, 6, 14, 16),
        handoverWindowEnd: DateTime(2026, 6, 14, 18),
      );

      expect(capturedData, isNotNull);
      expect(capturedData!['transportMode'], 'BOAT');
    });

    test('includes country codes in payload when provided', () async {
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
        departureCity: 'New York',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2024, 6, 1),
        pickupAddress: kPickup,
        deliveryAddress: kDelivery,
        availableKg: 10.0,
        pricePerKg: 12.0,
        transportMode: TransportMode.plane,
        departureCountryCode: 'US',
        arrivalCountryCode: 'SN',
        handoverWindowStart: DateTime(2026, 6, 14, 16),
        handoverWindowEnd: DateTime(2026, 6, 14, 18),
      );

      expect(capturedData, isNotNull);
      expect(capturedData!['departureCountryCode'], 'US');
      expect(capturedData!['arrivalCountryCode'], 'SN');
    });

    test('omits country code keys when null', () async {
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
        transportMode: TransportMode.plane,
        handoverWindowStart: DateTime(2026, 6, 14, 16),
        handoverWindowEnd: DateTime(2026, 6, 14, 18),
      );

      expect(capturedData, isNotNull);
      expect(capturedData!.containsKey('departureCountryCode'), isFalse);
      expect(capturedData!.containsKey('arrivalCountryCode'), isFalse);
    });
  });
}
