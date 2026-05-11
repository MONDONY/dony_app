import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<T> _ok<T>(T data, String path) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );

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

final _pageJson = <String, dynamic>{
  'content': [_prJson],
  'totalElements': 1,
  'number': 0,
  'size': 20,
};

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late PackageRequestRepository repo;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    repo = PackageRequestRepository(mockClient);
  });

  group('create', () {
    test('POSTs to /package-requests and returns PackageRequest', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/package-requests',
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => _ok(_prJson, '/package-requests'));

      final result = await repo.create(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        desiredDate: DateTime(2026, 6, 15),
        dateToleranceDays: 2,
        weightKg: 5.0,
        parcelSize: ParcelSize.small,
        transportMode: TransportMode.plane,
        contentCategory: 'vetements',
      );

      expect(result.id, 'pr-1');
      expect(result.parcelSize, ParcelSize.small);
      expect(result.status, PackageRequestStatus.open);
    });
  });

  group('findMine', () {
    test('GETs /package-requests/me and returns paginated results', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          '/package-requests/me',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => _ok(_pageJson, '/package-requests/me'));

      final page = await repo.findMine();

      expect(page.content.length, 1);
      expect(page.totalElements, 1);
      expect(page.page, 0);
      expect(page.content.first.departureCity, 'Paris');
    });
  });

  group('getById', () {
    test('GETs /package-requests/:id and returns PackageRequest', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>('/package-requests/pr-1'),
      ).thenAnswer((_) async => _ok(_prJson, '/package-requests/pr-1'));

      final result = await repo.getById('pr-1');

      expect(result.id, 'pr-1');
      expect(result.arrivalCity, 'Dakar');
    });
  });

  group('cancel', () {
    test('DELETEs /package-requests/:id', () async {
      when(
        () => mockDio.delete<void>('/package-requests/pr-1'),
      ).thenAnswer(
        (_) async => Response<void>(
          statusCode: 204,
          requestOptions: RequestOptions(path: '/package-requests/pr-1'),
        ),
      );

      await expectLater(repo.cancel('pr-1'), completes);
    });
  });

  group('search', () {
    final searchItemJson = <String, dynamic>{
      'id': 'pr-1',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'departureLat': 48.85,
      'departureLng': 2.35,
      'arrivalLat': 14.69,
      'arrivalLng': -17.44,
      'desiredDate': '2026-06-15',
      'dateToleranceDays': 2,
      'weightKg': 5.0,
      'parcelSize': 'SMALL',
      'contentCategory': 'vetements',
      'targetPriceEur': 25.0,
      'sender': {
        'id': 'sender-1',
        'displayName': 'Alice',
        'averageRating': 4.5,
        'totalRatings': 10,
        'kycVerified': true,
      },
    };

    test('GETs /package-requests with filters and returns page', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          '/package-requests',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => _ok({
            'content': [searchItemJson],
            'totalElements': 1,
            'number': 0,
            'size': 20,
          }, '/package-requests'));

      final page = await repo.search(departure: 'Paris', arrival: 'Dakar');

      expect(page.content.isNotEmpty, true);
      expect(page.content.first.departureLat, 48.85);
    });
  });
}
