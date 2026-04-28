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
      when(() => mockDio.post('/cancellations', data: any(named: 'data')))
          .thenAnswer((_) async =>
              _ok(_cancellationJson, '/cancellations'));

      final result = await datasource.cancelTrip(
        announcementId: 'ann-001',
        reason: 'TRAVELER_SICK',
      );

      expect(result.announcementId, 'ann-001');
      expect(result.affectedBidsCount, 2);
    });
  });

  group('getRematchSuggestions', () {
    test('returns list of suggestions', () async {
      when(() => mockDio.get('/cancellations/canc-1/rematch-suggestions'))
          .thenAnswer((_) async => _ok(
              [_suggestionJson],
              '/cancellations/canc-1/rematch-suggestions'));

      final results = await datasource.getRematchSuggestions('canc-1');

      expect(results, hasLength(1));
      expect(results.first.suggestionId, 'sug-1');
    });

    test('returns empty list when no suggestions', () async {
      when(() => mockDio.get('/cancellations/canc-x/rematch-suggestions'))
          .thenAnswer((_) async =>
              _ok([], '/cancellations/canc-x/rematch-suggestions'));

      final results = await datasource.getRematchSuggestions('canc-x');
      expect(results, isEmpty);
    });
  });
}
