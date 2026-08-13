import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/package_request/data/models/price_estimate.dart';
import 'package:dony/features/package_request/data/price_estimation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<T> _ok<T>(T data, String path) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: path),
);

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late PriceEstimationRepository repo;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    repo = PriceEstimationRepository(mockClient);
  });

  group('estimate', () {
    test(
      'GETs /package-requests/estimate and returns HIGH confidence estimate',
      () async {
        final estimateJson = <String, dynamic>{
          'lowEur': 85.0,
          'highEur': 115.0,
          'confidence': 'HIGH',
          'sampleSize': 15,
        };

        when(
          () => mockDio.get<Map<String, dynamic>>(
            '/package-requests/estimate',
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer(
          (_) async => _ok(estimateJson, '/package-requests/estimate'),
        );

        final estimate = await repo.estimate(
          from: 'Paris',
          to: 'Dakar',
          weight: 5.0,
        );

        expect(estimate.confidence, PriceEstimateConfidence.high);
        expect(estimate.lowEur, 85.0);
        expect(estimate.highEur, 115.0);
        expect(estimate.sampleSize, 15);
      },
    );

    test('returns LOW confidence estimate with null corridor', () async {
      final estimateJson = <String, dynamic>{
        'lowEur': null,
        'highEur': null,
        'confidence': 'LOW',
        'sampleSize': 0,
      };

      when(
        () => mockDio.get<Map<String, dynamic>>(
          '/package-requests/estimate',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _ok(estimateJson, '/package-requests/estimate'),
      );

      final estimate = await repo.estimate(
        from: 'Lyon',
        to: 'Bamako',
        weight: 2.0,
      );

      expect(estimate.confidence, PriceEstimateConfidence.low);
      expect(estimate.lowEur, isNull);
      expect(estimate.sampleSize, 0);
    });
  });
}
