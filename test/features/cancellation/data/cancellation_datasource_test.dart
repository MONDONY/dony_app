import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/cancellation/data/datasources/cancellation_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<dynamic> _ok(dynamic data, String path) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: path),
);

final _cancellationJson = {
  'announcementId': 'ann-001',
  'affectedBidsCount': 2,
  'reason': 'TRAVELER_SICK',
  'rematchSuggestions': [],
  'cancelledAt': '2024-01-15T00:00:00.000Z',
};

final _suggestionJson = {
  'suggestionId': 'sug-1',
  'announcementId': 'ann-002',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': '2024-02-01T00:00:00.000Z',
  'availableKg': 5.0,
  'pricePerKg': 12.0,
};

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late CancellationRemoteDatasource datasource;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    datasource = CancellationRemoteDatasource(mockClient);
  });

  group('cancelTrip', () {
    test('returns CancellationModel on success', () async {
      when(
        () => mockDio.post('/cancellations', data: any(named: 'data')),
      ).thenAnswer((_) async => _ok(_cancellationJson, '/cancellations'));

      final result = await datasource.cancelTrip(
        announcementId: 'ann-001',
        reason: 'TRAVELER_SICK',
      );

      expect(result.announcementId, 'ann-001');
      expect(result.affectedBidsCount, 2);
    });
  });

  group('reportNoShow', () {
    test('calls POST /cancellations/bids/{bidId}/report-noshow', () async {
      when(
        () => mockDio.post('/cancellations/bids/bid-1/report-noshow'),
      ).thenAnswer(
        (_) async => _ok(null, '/cancellations/bids/bid-1/report-noshow'),
      );

      await datasource.reportNoShow('bid-1');

      verify(
        () => mockDio.post('/cancellations/bids/bid-1/report-noshow'),
      ).called(1);
    });
  });

  group('contestNoShow', () {
    test('calls POST /cancellations/bids/{bidId}/contest-noshow', () async {
      when(
        () => mockDio.post('/cancellations/bids/bid-2/contest-noshow'),
      ).thenAnswer(
        (_) async => _ok(null, '/cancellations/bids/bid-2/contest-noshow'),
      );

      await datasource.contestNoShow('bid-2');

      verify(
        () => mockDio.post('/cancellations/bids/bid-2/contest-noshow'),
      ).called(1);
    });
  });

  group('reportDeliveryNoShow', () {
    test(
      'calls POST /cancellations/bids/{bidId}/report-delivery-noshow',
      () async {
        when(
          () =>
              mockDio.post('/cancellations/bids/bid-4/report-delivery-noshow'),
        ).thenAnswer(
          (_) async =>
              _ok(null, '/cancellations/bids/bid-4/report-delivery-noshow'),
        );

        await datasource.reportDeliveryNoShow('bid-4');

        verify(
          () =>
              mockDio.post('/cancellations/bids/bid-4/report-delivery-noshow'),
        ).called(1);
      },
    );
  });

  group('reportTravelerDeliveryNoShow', () {
    test(
      'calls POST /cancellations/bids/{bidId}/report-traveler-delivery-noshow',
      () async {
        when(
          () => mockDio.post(
            '/cancellations/bids/bid-5/report-traveler-delivery-noshow',
          ),
        ).thenAnswer(
          (_) async => _ok(
            null,
            '/cancellations/bids/bid-5/report-traveler-delivery-noshow',
          ),
        );

        await datasource.reportTravelerDeliveryNoShow('bid-5');

        verify(
          () => mockDio.post(
            '/cancellations/bids/bid-5/report-traveler-delivery-noshow',
          ),
        ).called(1);
      },
    );
  });

  group('contestDeliveryNoShow', () {
    test(
      'calls POST /cancellations/bids/{bidId}/contest-delivery-noshow',
      () async {
        when(
          () =>
              mockDio.post('/cancellations/bids/bid-6/contest-delivery-noshow'),
        ).thenAnswer(
          (_) async =>
              _ok(null, '/cancellations/bids/bid-6/contest-delivery-noshow'),
        );

        await datasource.contestDeliveryNoShow('bid-6');

        verify(
          () =>
              mockDio.post('/cancellations/bids/bid-6/contest-delivery-noshow'),
        ).called(1);
      },
    );
  });

  group('confirmNoShow', () {
    test(
      'calls POST /cancellations/bids/{bidId}/confirm-noshow-self',
      () async {
        when(
          () => mockDio.post('/cancellations/bids/bid-3/confirm-noshow-self'),
        ).thenAnswer(
          (_) async =>
              _ok(null, '/cancellations/bids/bid-3/confirm-noshow-self'),
        );

        await datasource.confirmNoShow('bid-3');

        verify(
          () => mockDio.post('/cancellations/bids/bid-3/confirm-noshow-self'),
        ).called(1);
      },
    );
  });

  group('cancelAfterHandover', () {
    test('calls POST /bids/{bidId}/cancel-after-handover', () async {
      when(
        () => mockDio.post('/bids/bid-9/cancel-after-handover'),
      ).thenAnswer((_) async => _ok(null, '/bids/bid-9/cancel-after-handover'));

      await datasource.cancelAfterHandover('bid-9');

      verify(() => mockDio.post('/bids/bid-9/cancel-after-handover')).called(1);
    });
  });

  group('confirmReturn', () {
    test('POST confirm-return with code body → ReturnCodeModel', () async {
      when(
        () => mockDio.post(
          '/cancellations/bids/bid-9/confirm-return',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _ok({
          'returnCode': null,
          'returnDeadline': '2024-06-04T10:00:00.000Z',
          'returnedAt': '2024-06-02T09:00:00.000Z',
        }, '/cancellations/bids/bid-9/confirm-return'),
      );

      final result = await datasource.confirmReturn('bid-9', '123456');

      expect(result.isReturned, true);
      verify(
        () => mockDio.post(
          '/cancellations/bids/bid-9/confirm-return',
          data: {'returnCode': '123456'},
        ),
      ).called(1);
    });
  });

  group('getReturnCode', () {
    test('GET return-code → ReturnCodeModel with code + deadline', () async {
      when(
        () => mockDio.get('/cancellations/bids/bid-9/return-code'),
      ).thenAnswer(
        (_) async => _ok({
          'returnCode': '654321',
          'returnDeadline': '2024-06-04T10:00:00.000Z',
          'returnedAt': null,
        }, '/cancellations/bids/bid-9/return-code'),
      );

      final result = await datasource.getReturnCode('bid-9');

      expect(result.returnCode, '654321');
      expect(result.isReturned, false);
    });
  });

  group('getRematchSuggestions', () {
    test('returns list of suggestions', () async {
      when(
        () => mockDio.get('/cancellations/canc-1/rematch-suggestions'),
      ).thenAnswer(
        (_) async =>
            _ok([_suggestionJson], '/cancellations/canc-1/rematch-suggestions'),
      );

      final results = await datasource.getRematchSuggestions('canc-1');

      expect(results, hasLength(1));
      expect(results.first.suggestionId, 'sug-1');
    });

    test('returns empty list when no suggestions', () async {
      when(
        () => mockDio.get('/cancellations/canc-x/rematch-suggestions'),
      ).thenAnswer(
        (_) async => _ok([], '/cancellations/canc-x/rematch-suggestions'),
      );

      final results = await datasource.getRematchSuggestions('canc-x');
      expect(results, isEmpty);
    });
  });
}
