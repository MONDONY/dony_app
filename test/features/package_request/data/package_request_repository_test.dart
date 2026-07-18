import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
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
        categories: const ['Vêtements'],
        negotiable: true,
        acceptedPaymentMethods: {PaymentMethod.stripe},
      );

      expect(result.id, 'pr-1');
      expect(result.parcelSize, ParcelSize.small);
      expect(result.status, PackageRequestStatus.open);
    });

    test(
      'create payload includes negotiable, acceptedPaymentMethods and totalBudgetEur',
      () async {
        Map<String, dynamic>? capturedBody;

        when(
          () => mockDio.post<Map<String, dynamic>>(
            '/package-requests',
            data: any(named: 'data'),
          ),
        ).thenAnswer((invocation) async {
          capturedBody =
              invocation.namedArguments[#data] as Map<String, dynamic>;
          return _ok(_prJson, '/package-requests');
        });

        await repo.create(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: DateTime(2026, 6, 15),
          dateToleranceDays: 2,
          weightKg: 5.0,
          parcelSize: ParcelSize.small,
          transportMode: TransportMode.plane,
          categories: const ['Vêtements', 'Médicaments', 'Fragile'],
          negotiable: true,
          acceptedPaymentMethods: {PaymentMethod.stripe, PaymentMethod.cash},
          totalBudgetEur: 50.0,
        );

        expect(capturedBody, isNotNull);
        expect(capturedBody!['negotiable'], true);
        expect(capturedBody!['totalBudgetEur'], 50.0);
        final methods =
            capturedBody!['acceptedPaymentMethods'] as List<dynamic>;
        expect(methods, containsAll(['STRIPE', 'CASH']));
        // Régression : le backend exige parcelSize + transportMode (@NotNull).
        // Les omettre renvoyait un 422 « Validation failed » à la publication.
        expect(capturedBody!['parcelSize'], 'SMALL');
        expect(capturedBody!['transportMode'], 'PLANE');
        // Catégories multiples → chaîne jointe par virgule côté wire.
        expect(
          capturedBody!['contentCategory'],
          'Vêtements,Médicaments,Fragile',
        );
      },
    );
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
      when(() => mockDio.delete<void>('/package-requests/pr-1')).thenAnswer(
        (_) async => Response<void>(
          statusCode: 204,
          requestOptions: RequestOptions(path: '/package-requests/pr-1'),
        ),
      );

      await expectLater(repo.cancel('pr-1'), completes);
    });
  });

  group('completeDetails', () {
    test('POSTs recipientName, recipientPhone and recipientCity', () async {
      Map<String, dynamic>? capturedBody;
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/package-requests/pr-1/complete-details',
          data: any(named: 'data'),
        ),
      ).thenAnswer((invocation) async {
        capturedBody = invocation.namedArguments[#data] as Map<String, dynamic>;
        return _ok(_prJson, '/package-requests/pr-1/complete-details');
      });

      final result = await repo.completeDetails(
        'pr-1',
        recipientName: 'Fatou Diop',
        recipientPhone: '+221771234567',
        recipientCity: 'Dakar',
        declaredValueEur: 120.0,
      );

      expect(result.id, 'pr-1');
      expect(capturedBody, isNotNull);
      expect(capturedBody!['recipientName'], 'Fatou Diop');
      expect(capturedBody!['recipientPhone'], '+221771234567');
      expect(capturedBody!['recipientCity'], 'Dakar');
      // Removed legacy fields must not be sent.
      expect(capturedBody!.containsKey('pickupAddressLabel'), false);
      expect(capturedBody!.containsKey('pickupLat'), false);
      expect(capturedBody!.containsKey('pickupLng'), false);
      expect(capturedBody!.containsKey('deliveryAddressLabel'), false);
      expect(capturedBody!.containsKey('deliveryLat'), false);
      expect(capturedBody!.containsKey('deliveryLng'), false);
      expect(capturedBody!['declaredValueEur'], 120.0);
      expect(capturedBody!.containsKey('disclaimerSigned'), false);
    });

    test('omits recipientCity when null', () async {
      Map<String, dynamic>? capturedBody;
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/package-requests/pr-1/complete-details',
          data: any(named: 'data'),
        ),
      ).thenAnswer((invocation) async {
        capturedBody = invocation.namedArguments[#data] as Map<String, dynamic>;
        return _ok(_prJson, '/package-requests/pr-1/complete-details');
      });

      await repo.completeDetails(
        'pr-1',
        recipientName: 'Fatou Diop',
        recipientPhone: '+221771234567',
        declaredValueEur: 120.0,
      );

      expect(capturedBody!.containsKey('recipientCity'), false);
    });

    test('omits recipientCity when empty string', () async {
      Map<String, dynamic>? capturedBody;
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/package-requests/pr-1/complete-details',
          data: any(named: 'data'),
        ),
      ).thenAnswer((invocation) async {
        capturedBody = invocation.namedArguments[#data] as Map<String, dynamic>;
        return _ok(_prJson, '/package-requests/pr-1/complete-details');
      });

      await repo.completeDetails(
        'pr-1',
        recipientName: 'Fatou Diop',
        recipientPhone: '+221771234567',
        recipientCity: '',
        declaredValueEur: 120.0,
      );

      expect(capturedBody!.containsKey('recipientCity'), false);
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
      ).thenAnswer(
        (_) async => _ok({
          'content': [searchItemJson],
          'totalElements': 1,
          'number': 0,
          'size': 20,
        }, '/package-requests'),
      );

      final page = await repo.search(departure: 'Paris', arrival: 'Dakar');

      expect(page.content.isNotEmpty, true);
      expect(page.content.first.departureLat, 48.85);
    });

    test('sends urgent=true when urgent: true', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          '/package-requests',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _ok({
          'content': <dynamic>[],
          'totalElements': 0,
          'number': 0,
          'size': 20,
        }, '/package-requests'),
      );

      await repo.search(urgent: true);

      final captured = verify(
        () => mockDio.get<Map<String, dynamic>>(
          '/package-requests',
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(captured['urgent'], true);
    });

    test(
        'omits urgent param when urgent is false or null (never sends urgent=false)',
        () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          '/package-requests',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _ok({
          'content': <dynamic>[],
          'totalElements': 0,
          'number': 0,
          'size': 20,
        }, '/package-requests'),
      );

      await repo.search(urgent: false);
      await repo.search();

      final calls = verify(
        () => mockDio.get<Map<String, dynamic>>(
          '/package-requests',
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured;
      for (final c in calls) {
        expect((c as Map<String, dynamic>).containsKey('urgent'), isFalse);
      }
    });
  });

  group('photoKeys', () {
    test('create sends photoKeys when provided', () async {
      Map<String, dynamic>? body;
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/package-requests',
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        body = inv.namedArguments[#data] as Map<String, dynamic>;
        return _ok(_prJson, '/package-requests');
      });
      await repo.create(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        desiredDate: DateTime(2026, 6, 15),
        dateToleranceDays: 2,
        weightKg: 5.0,
        parcelSize: ParcelSize.small,
        transportMode: TransportMode.plane,
        categories: const ['Vêtements'],
        negotiable: true,
        acceptedPaymentMethods: {PaymentMethod.stripe},
        photoKeys: const [
          'package_requests/s/1.jpg',
          'package_requests/s/2.jpg',
        ],
      );
      expect(body!['photoKeys'], [
        'package_requests/s/1.jpg',
        'package_requests/s/2.jpg',
      ]);
    });

    test('create omits photoKeys when empty', () async {
      Map<String, dynamic>? body;
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/package-requests',
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        body = inv.namedArguments[#data] as Map<String, dynamic>;
        return _ok(_prJson, '/package-requests');
      });
      await repo.create(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        desiredDate: DateTime(2026, 6, 15),
        dateToleranceDays: 2,
        weightKg: 5.0,
        parcelSize: ParcelSize.small,
        transportMode: TransportMode.plane,
        categories: const ['Vêtements'],
        negotiable: true,
        acceptedPaymentMethods: {PaymentMethod.stripe},
        photoKeys: const [],
      );
      expect(body!.containsKey('photoKeys'), false);
    });

    test('update sends photoKeys', () async {
      Map<String, dynamic>? body;
      when(
        () => mockDio.put<Map<String, dynamic>>(
          '/package-requests/pr-1',
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        body = inv.namedArguments[#data] as Map<String, dynamic>;
        return _ok(_prJson, '/package-requests/pr-1');
      });
      await repo.update(
        'pr-1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        desiredDate: DateTime(2026, 6, 15),
        dateToleranceDays: 2,
        weightKg: 5.0,
        parcelSize: ParcelSize.small,
        transportMode: TransportMode.plane,
        categories: const ['Vêtements'],
        negotiable: true,
        acceptedPaymentMethods: {PaymentMethod.stripe},
        photoKeys: const ['package_requests/s/9.jpg'],
      );
      expect(body!['photoKeys'], ['package_requests/s/9.jpg']);
    });

    test('uploadPhotoKey returns the S3 key', () async {
      final tmp = File(
        '${Directory.systemTemp.path}/dony_t_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await tmp.writeAsBytes([1, 2, 3]);
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync();
      });
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/storage/upload/package-request',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _ok({
          'key': 'package_requests/s/x.jpg',
          'url': 'https://signed/x',
        }, '/storage/upload/package-request'),
      );
      final key = await repo.uploadPhotoKey(tmp);
      expect(key, 'package_requests/s/x.jpg');
    });
  });

  group('report', () {
    test('POSTs reason + details to /package-requests/:id/report', () async {
      Map<String, dynamic>? body;
      when(
        () => mockDio.post<void>(
          '/package-requests/pr-1/report',
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        body = inv.namedArguments[#data] as Map<String, dynamic>;
        return Response<void>(
          statusCode: 204,
          requestOptions: RequestOptions(path: '/package-requests/pr-1/report'),
        );
      });
      await repo.report('pr-1', reason: 'SCAM', details: 'arnaque');
      expect(body!['reason'], 'SCAM');
      expect(body!['details'], 'arnaque');
    });

    test('omits details when null', () async {
      Map<String, dynamic>? body;
      when(
        () => mockDio.post<void>(
          '/package-requests/pr-1/report',
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        body = inv.namedArguments[#data] as Map<String, dynamic>;
        return Response<void>(
          statusCode: 204,
          requestOptions: RequestOptions(path: '/package-requests/pr-1/report'),
        );
      });
      await repo.report('pr-1', reason: 'OTHER');
      expect(body!.containsKey('details'), false);
    });
  });

  group('photos parsing', () {
    test('PackageRequest.fromJson maps photos to photoUrls + photoKeys', () {
      final json = <String, dynamic>{
        ..._prJson,
        'photos': [
          {
            'id': 'p1',
            'objectKey': 'package_requests/s/1.jpg',
            'url': 'https://signed/1',
          },
          {
            'id': 'p2',
            'objectKey': 'package_requests/s/2.jpg',
            'url': 'https://signed/2',
          },
        ],
      };
      final pr = PackageRequest.fromJson(json);
      expect(pr.photoUrls, ['https://signed/1', 'https://signed/2']);
      expect(pr.photoKeys, [
        'package_requests/s/1.jpg',
        'package_requests/s/2.jpg',
      ]);
    });

    test(
      'PackageRequestSearchItem.fromJson maps photos; empty when absent',
      () {
        final base = <String, dynamic>{
          'id': 'pr-1',
          'departureCity': 'Paris',
          'arrivalCity': 'Dakar',
          'desiredDate': '2026-06-15',
          'dateToleranceDays': 2,
          'weightKg': 5.0,
          'parcelSize': 'SMALL',
          'contentCategory': 'vetements',
          'sender': {
            'id': 's',
            'displayName': 'A',
            'averageRating': 4.5,
            'totalRatings': 3,
            'kycVerified': true,
          },
        };
        final withPhotos = <String, dynamic>{
          ...base,
          'photos': [
            {'id': 'p1', 'url': 'https://s/1'},
          ],
        };
        expect(PackageRequestSearchItem.fromJson(withPhotos).photoUrls, [
          'https://s/1',
        ]);
        expect(PackageRequestSearchItem.fromJson(base).photoUrls, isEmpty);
      },
    );
  });
}
