// ignore_for_file: avoid_redundant_argument_values

import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/favorites/data/datasources/favorite_remote_datasource.dart';
import 'package:dony/features/favorites/data/models/favorite_ids.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Response<dynamic> _ok(dynamic data, String path) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );

Response<dynamic> _noContent(String path) => Response(
      data: null,
      statusCode: 204,
      requestOptions: RequestOptions(path: path),
    );

void main() {
  late _MockApiClient client;
  late _MockDio dio;
  late FavoriteRemoteDatasource ds;

  setUp(() {
    client = _MockApiClient();
    dio = _MockDio();
    when(() => client.dio).thenReturn(dio);
    ds = FavoriteRemoteDatasource(client);
  });

  // ---------------------------------------------------------------------------
  // add()
  // ---------------------------------------------------------------------------
  group('add()', () {
    test('calls PUT /favorites/trip/<id>', () async {
      when(() => dio.put('/favorites/trip/t1'))
          .thenAnswer((_) async => _noContent('/favorites/trip/t1'));

      await ds.add('trip', 't1');

      verify(() => dio.put('/favorites/trip/t1')).called(1);
    });

    test('calls PUT /favorites/package-request/<id>', () async {
      when(() => dio.put('/favorites/package-request/r1'))
          .thenAnswer((_) async => _noContent('/favorites/package-request/r1'));

      await ds.add('package-request', 'r1');

      verify(() => dio.put('/favorites/package-request/r1')).called(1);
    });

    test('propagates error from dio.put', () async {
      when(() => dio.put(any()))
          .thenAnswer((_) async => throw Exception('network'));

      await expectLater(ds.add('trip', 't1'), throwsException);
    });
  });

  // ---------------------------------------------------------------------------
  // remove()
  // ---------------------------------------------------------------------------
  group('remove()', () {
    test('calls DELETE /favorites/trip/<id>', () async {
      when(() => dio.delete('/favorites/trip/t1'))
          .thenAnswer((_) async => _noContent('/favorites/trip/t1'));

      await ds.remove('trip', 't1');

      verify(() => dio.delete('/favorites/trip/t1')).called(1);
    });

    test('calls DELETE /favorites/package-request/<id>', () async {
      when(() => dio.delete('/favorites/package-request/r1'))
          .thenAnswer((_) async => _noContent('/favorites/package-request/r1'));

      await ds.remove('package-request', 'r1');

      verify(() => dio.delete('/favorites/package-request/r1')).called(1);
    });

    test('propagates error from dio.delete', () async {
      when(() => dio.delete(any()))
          .thenAnswer((_) async => throw Exception('network'));

      await expectLater(ds.remove('trip', 't1'), throwsException);
    });
  });

  // ---------------------------------------------------------------------------
  // ids()
  // ---------------------------------------------------------------------------
  group('ids()', () {
    test('calls GET /favorites/ids and parses FavoriteIds', () async {
      when(() => dio.get('/favorites/ids')).thenAnswer(
        (_) async => _ok({
          'trips': ['t1', 't2'],
          'packageRequests': ['r1'],
        }, '/favorites/ids'),
      );

      final result = await ds.ids();

      expect(result, isA<FavoriteIds>());
      expect(result.trips, containsAll(['t1', 't2']));
      expect(result.packageRequests, contains('r1'));
    });

    test('returns empty sets when lists are absent', () async {
      when(() => dio.get('/favorites/ids')).thenAnswer(
        (_) async => _ok(<String, dynamic>{}, '/favorites/ids'),
      );

      final result = await ds.ids();

      expect(result.trips, isEmpty);
      expect(result.packageRequests, isEmpty);
    });

    test('propagates error from dio.get', () async {
      when(() => dio.get('/favorites/ids'))
          .thenAnswer((_) async => throw Exception('network'));

      await expectLater(ds.ids(), throwsException);
    });
  });

  // ---------------------------------------------------------------------------
  // trips()
  // ---------------------------------------------------------------------------
  group('trips()', () {
    test('calls GET /favorites/trips and maps list', () async {
      when(() => dio.get('/favorites/trips')).thenAnswer(
        (_) async => _ok([
          {
            'id': 'trip-1',
            'travelerId': 'tv1',
            'departureCity': 'Paris',
            'arrivalCity': 'Dakar',
            'departureDate':
                DateTime.now().add(const Duration(days: 5)).toIso8601String(),
            'totalKg': 20.0,
            'availableKg': 15.0,
            'pricePerKg': 8.0,
            'pricingMode': 'KG',
            'status': 'ACTIVE',
            'pendingBidCount': 0,
            'confirmedParcelCount': 0,
            'createdAt': '2024-01-01T00:00:00Z',
            'updatedAt': '2024-01-01T00:00:00Z',
          },
        ], '/favorites/trips'),
      );

      final result = await ds.trips();

      expect(result, hasLength(1));
      expect(result.first.id, 'trip-1');
      expect(result.first.departureCity, 'Paris');
    });

    test('returns empty list when response is empty', () async {
      when(() => dio.get('/favorites/trips'))
          .thenAnswer((_) async => _ok([], '/favorites/trips'));

      final result = await ds.trips();

      expect(result, isEmpty);
    });

    test('propagates error from dio.get', () async {
      when(() => dio.get('/favorites/trips'))
          .thenAnswer((_) async => throw Exception('network'));

      await expectLater(ds.trips(), throwsException);
    });
  });

  // ---------------------------------------------------------------------------
  // packageRequests()
  // ---------------------------------------------------------------------------
  group('packageRequests()', () {
    test('calls GET /favorites/package-requests and maps list', () async {
      when(() => dio.get('/favorites/package-requests')).thenAnswer(
        (_) async => _ok([
          {
            'id': 'req-1',
            'departureCity': 'Lyon',
            'arrivalCity': 'Abidjan',
            'desiredDate': '2025-07-01',
            'dateToleranceDays': 3,
            'weightKg': 4.0,
            'parcelSize': 'MEDIUM',
            'sender': {
              'id': 's1',
              'displayName': 'Moussa',
              'averageRating': 4.5,
              'totalRatings': 8,
              'kycVerified': true,
            },
          },
        ], '/favorites/package-requests'),
      );

      final result = await ds.packageRequests();

      expect(result, hasLength(1));
      expect(result.first.id, 'req-1');
      expect(result.first.departureCity, 'Lyon');
    });

    test('returns empty list when response is empty', () async {
      when(() => dio.get('/favorites/package-requests'))
          .thenAnswer((_) async => _ok([], '/favorites/package-requests'));

      final result = await ds.packageRequests();

      expect(result, isEmpty);
    });

    test('propagates error from dio.get', () async {
      when(() => dio.get('/favorites/package-requests'))
          .thenAnswer((_) async => throw Exception('network'));

      await expectLater(ds.packageRequests(), throwsException);
    });
  });
}
