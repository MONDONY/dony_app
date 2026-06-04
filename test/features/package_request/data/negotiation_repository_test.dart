import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<T> _ok<T>(T data, String path) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );

const _threadJson = <String, dynamic>{
  'id': 'th-1',
  'packageRequestId': 'pr-1',
  'travelerId': 'tr-1',
  'travelerAnnouncementId': null,
  'travelerTravelDate': '2026-06-15',
  'travelerAvailableKg': 10.0,
  'status': 'OPEN',
  'currentPriceEur': 30.0,
  'roundsCount': 1,
  'lastActivityAt': '2026-05-10T10:00:00Z',
  'createdAt': '2026-05-10T10:00:00Z',
  'messages': <dynamic>[],
  'paymentIntentClientSecret': null,
};

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late NegotiationRepository repo;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    repo = NegotiationRepository(mockClient);
  });

  group('start', () {
    test('POSTs to /negotiations and returns NegotiationThread', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations',
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => _ok(_threadJson, '/negotiations'));

      final thread = await repo.start(
        packageRequestId: 'pr-1',
        proposedPriceEur: 30.0,
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10.0,
      );

      expect(thread.id, 'th-1');
      expect(thread.status, NegotiationThreadStatus.open);
      expect(thread.currentPriceEur, 30.0);
    });
  });

  group('findMine', () {
    test('GETs /negotiations/me and returns list of threads', () async {
      when(
        () => mockDio.get<List<dynamic>>('/negotiations/me'),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          data: [_threadJson],
          statusCode: 200,
          requestOptions: RequestOptions(path: '/negotiations/me'),
        ),
      );

      final threads = await repo.findMine();

      expect(threads.length, 1);
      expect(threads.first.packageRequestId, 'pr-1');
    });
  });

  group('counter', () {
    test('POSTs to /negotiations/:id/counter and returns updated thread',
        () async {
      final counterJson = {
        ..._threadJson,
        'currentPriceEur': 28.0,
        'roundsCount': 2,
      };

      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/counter',
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => _ok(counterJson, '/negotiations/th-1/counter'));

      final thread = await repo.counter('th-1', proposedPriceEur: 28.0);

      expect(thread.currentPriceEur, 28.0);
      expect(thread.roundsCount, 2);
    });
  });

  group('accept', () {
    test('POSTs to /negotiations/:id/accept and returns accepted thread',
        () async {
      final acceptedJson = {
        ..._threadJson,
        'status': 'ACCEPTED',
        'paymentIntentClientSecret': 'pi_secret_123',
      };

      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/accept',
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => _ok(acceptedJson, '/negotiations/th-1/accept'));

      final thread = await repo.accept('th-1');

      expect(thread.status, NegotiationThreadStatus.accepted);
      expect(thread.paymentIntentClientSecret, 'pi_secret_123');
    });
  });

  group('reject', () {
    test('POSTs to /negotiations/:id/reject', () async {
      when(
        () => mockDio.post<void>(
          '/negotiations/th-1/reject',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<void>(
          statusCode: 204,
          requestOptions: RequestOptions(path: '/negotiations/th-1/reject'),
        ),
      );

      await expectLater(repo.reject('th-1', reason: 'Not convenient'), completes);
    });
  });

  group('getById', () {
    test('GETs /negotiations/:id and returns NegotiationThread', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>('/negotiations/th-1'),
      ).thenAnswer((_) async => _ok(_threadJson, '/negotiations/th-1'));

      final thread = await repo.getById('th-1');
      expect(thread.id, 'th-1');
    });
  });

  group('submitTrip', () {
    test('POSTs to /negotiations/:id/submit-trip and returns updated thread',
        () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/submit-trip',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
          (_) async => _ok(_threadJson, '/negotiations/th-1/submit-trip'));

      final thread = await repo.submitTrip(
        'th-1',
        travelerAnnouncementId: 'ann-1',
        paymentMethod: PaymentMethod.stripe,
      );
      expect(thread.id, 'th-1');
    });
  });

  group('initiatePayment', () {
    test('POSTs to /negotiations/:id/initiate-payment and returns secrets',
        () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/initiate-payment',
        ),
      ).thenAnswer(
        (_) async => _ok({
          'clientSecret': 'pi_test_secret',
          'stripePaymentIntentId': 'pi_test_id',
        }, '/negotiations/th-1/initiate-payment'),
      );

      final result = await repo.initiatePayment('th-1');
      expect(result.clientSecret, 'pi_test_secret');
      expect(result.paymentIntentId, 'pi_test_id');
    });
  });

  group('checkout', () {
    test('POSTs to /negotiations/:id/checkout and returns thread', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/checkout',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
          (_) async => _ok(_threadJson, '/negotiations/th-1/checkout'));

      final thread =
          await repo.checkout('th-1', paymentIntentId: 'pi_test_id');
      expect(thread.id, 'th-1');
    });
  });

  group('refuseTrip', () {
    test('POSTs to /negotiations/:id/refuse-trip and returns thread',
        () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/refuse-trip',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
          (_) async => _ok(_threadJson, '/negotiations/th-1/refuse-trip'));

      final thread = await repo.refuseTrip('th-1', reason: 'Wrong date');
      expect(thread.id, 'th-1');
    });

    test('POSTs to /negotiations/:id/refuse-trip with no data when reason is null',
        () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/refuse-trip',
          data: null,
        ),
      ).thenAnswer(
          (_) async => _ok(_threadJson, '/negotiations/th-1/refuse-trip'));

      final thread = await repo.refuseTrip('th-1');
      expect(thread.id, 'th-1');
    });
  });
}
