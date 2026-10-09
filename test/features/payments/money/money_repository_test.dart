import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/payments/money/data/datasources/money_remote_datasource.dart';
import 'package:dony/features/payments/money/data/repositories/money_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'money_fixtures.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late MoneyRepository repository;

  setUp(() {
    final client = MockApiClient();
    dio = MockDio();
    when(() => client.dio).thenReturn(dio);
    repository = MoneyRepository(MoneyRemoteDatasource(client));
  });

  void failWith(AppException error) {
    when(() => dio.get<dynamic>('/payments/me/overview')).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/payments/me/overview'),
        error: error,
      ),
    );
  }

  test('lit GET /payments/me/overview', () async {
    when(() => dio.get<dynamic>('/payments/me/overview')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/payments/me/overview'),
        statusCode: 200,
        data: overviewJson(),
      ),
    );
    final m = await repository.getOverview();
    expect(m.travelerItems, hasLength(4));
  });

  test('404 (ancien back) → MoneyOverviewUnavailable', () async {
    failWith(const NotFoundException());
    expect(repository.getOverview(), throwsA(isA<MoneyOverviewUnavailable>()));
  });

  test('405 (ancien back) → MoneyOverviewUnavailable', () async {
    failWith(const NetworkException('Method Not Allowed', code: '405'));
    expect(repository.getOverview(), throwsA(isA<MoneyOverviewUnavailable>()));
  });

  test('code serveur method-not-allowed → MoneyOverviewUnavailable', () async {
    failWith(
      const NetworkException('Method Not Allowed', code: 'method-not-allowed'),
    );
    expect(repository.getOverview(), throwsA(isA<MoneyOverviewUnavailable>()));
  });

  test('autre erreur → AppException remontée telle quelle', () async {
    failWith(const ServerException());
    expect(repository.getOverview(), throwsA(isA<ServerException>()));
  });
}
