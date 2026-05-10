import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
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
}
