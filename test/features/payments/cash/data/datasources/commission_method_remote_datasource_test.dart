import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/payments/cash/data/datasources/commission_method_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<dynamic> _ok(dynamic data, String path) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late CommissionMethodRemoteDatasource ds;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    ds = CommissionMethodRemoteDatasource(mockClient);
  });

  test('setup() POSTs and returns clientSecret', () async {
    when(() => mockDio.post('/traveler/commission-method/setup'))
        .thenAnswer((_) async => _ok({'clientSecret': 'seti_x'}, '/traveler/commission-method/setup'));

    final secret = await ds.setup();
    expect(secret, 'seti_x');
  });

  test('get() returns CommissionMethod when found', () async {
    when(() => mockDio.get('/traveler/commission-method'))
        .thenAnswer((_) async => _ok({
              'brand': 'visa',
              'last4': '4242',
              'expMonth': 12,
              'expYear': 2028,
              'expirationStatus': 'VALID',
            }, '/traveler/commission-method'));

    final result = await ds.get();
    expect(result, isNotNull);
    expect(result!.brand, 'visa');
    expect(result.last4, '4242');
  });

  test('get() returns null on 404', () async {
    when(() => mockDio.get('/traveler/commission-method')).thenThrow(
      DioException(
        response: Response(statusCode: 404, requestOptions: RequestOptions(path: '/traveler/commission-method')),
        requestOptions: RequestOptions(path: '/traveler/commission-method'),
      ),
    );

    final result = await ds.get();
    expect(result, isNull);
  });

  test('get() rethrows non-404 errors', () async {
    when(() => mockDio.get('/traveler/commission-method')).thenThrow(
      DioException(
        response: Response(statusCode: 500, requestOptions: RequestOptions(path: '/traveler/commission-method')),
        requestOptions: RequestOptions(path: '/traveler/commission-method'),
      ),
    );

    expect(() => ds.get(), throwsA(isA<DioException>()));
  });

  test('delete() calls DELETE endpoint without throwing', () async {
    when(() => mockDio.delete('/traveler/commission-method'))
        .thenAnswer((_) async => Response(statusCode: 204, requestOptions: RequestOptions(path: '/traveler/commission-method')));

    await ds.delete();
    verify(() => mockDio.delete('/traveler/commission-method')).called(1);
  });
}
