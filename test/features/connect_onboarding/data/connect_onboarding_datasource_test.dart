import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_datasource.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

class MockConnectOnboardingDatasource extends Mock
    implements ConnectOnboardingDatasource {}

Response<dynamic> _response(Map<String, dynamic>? data) =>
    Response(data: data, requestOptions: RequestOptions(), statusCode: 200);

void main() {
  late MockApiClient mockApi;
  late MockDio mockDio;
  late ConnectOnboardingDatasource datasource;

  setUp(() {
    mockApi = MockApiClient();
    mockDio = MockDio();
    when(() => mockApi.dio).thenReturn(mockDio);
    datasource = ConnectOnboardingDatasource(mockApi);
  });

  group('ConnectOnboardingDatasource', () {
    test('getAccountStatus lit GET /payments/connect/account', () async {
      when(() => mockDio.get('/payments/connect/account')).thenAnswer(
        (_) async => _response({
          'stripeAccountId': 'acct_123',
          'stripeAccountStatus': 'PENDING_ONBOARDING',
        }),
      );

      final status = await datasource.getAccountStatus();

      expect(status.accountId, 'acct_123');
      expect(status.needsOnboarding, isTrue);
    });

    test(
      'createConnectAccount poste sur /payments/connect/account et parse le statut',
      () async {
        when(() => mockDio.post('/payments/connect/account')).thenAnswer(
          (_) async => _response({
            'stripeAccountId': 'acct_456',
            'stripeAccountStatus': 'PENDING_ONBOARDING',
          }),
        );

        final status = await datasource.createConnectAccount();

        expect(status.accountId, 'acct_456');
        expect(status.isComplete, isFalse);
        verify(() => mockDio.post('/payments/connect/account')).called(1);
      },
    );

    test('createOnboardingLink renvoie l\'URL du corps', () async {
      when(() => mockDio.post('/payments/connect/onboarding-link')).thenAnswer(
        (_) async => _response({'url': 'https://connect.stripe.com/setup/abc'}),
      );

      final url = await datasource.createOnboardingLink();

      expect(url, 'https://connect.stripe.com/setup/abc');
    });
  });

  group('ConnectOnboardingRepository', () {
    late MockConnectOnboardingDatasource mockDatasource;
    late ConnectOnboardingRepository repository;

    setUp(() {
      mockDatasource = MockConnectOnboardingDatasource();
      repository = ConnectOnboardingRepository(mockDatasource);
    });

    test('createConnectAccount délègue au datasource', () async {
      when(() => mockDatasource.createConnectAccount()).thenAnswer(
        (_) async => const ConnectAccountStatus(status: 'PENDING_ONBOARDING'),
      );

      final status = await repository.createConnectAccount();

      expect(status.needsOnboarding, isTrue);
      verify(() => mockDatasource.createConnectAccount()).called(1);
    });

    test(
      'createConnectAccount traduit une DioException en AppException',
      () async {
        when(() => mockDatasource.createConnectAccount()).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              requestOptions: RequestOptions(),
              statusCode: 409,
              data: {'code': 'stripe-account-required'},
            ),
          ),
        );

        expect(
          () => repository.createConnectAccount(),
          throwsA(isA<AppException>()),
        );
      },
    );

    test('getAccountStatus délègue au datasource', () async {
      when(() => mockDatasource.getAccountStatus()).thenAnswer(
        (_) async => const ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
      );

      final status = await repository.getAccountStatus();

      expect(status.isComplete, isTrue);
    });

    test('createOnboardingLink délègue au datasource', () async {
      when(
        () => mockDatasource.createOnboardingLink(),
      ).thenAnswer((_) async => 'https://connect.stripe.com/setup/xyz');

      expect(
        await repository.createOnboardingLink(),
        'https://connect.stripe.com/setup/xyz',
      );
    });

    test(
      'createOnboardingLink traduit une DioException en AppException',
      () async {
        when(
          () => mockDatasource.createOnboardingLink(),
        ).thenThrow(DioException(requestOptions: RequestOptions()));

        expect(
          () => repository.createOnboardingLink(),
          throwsA(isA<AppException>()),
        );
      },
    );
  });
}
