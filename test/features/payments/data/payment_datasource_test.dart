import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:dony/features/payments/data/models/connect_account_model.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<dynamic> _ok(dynamic data, String path) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );

final _connectJson = {
  'stripeAccountId': 'acct_123',
  'stripeOnboarded': true,
};

final _paymentJson = {
  'id': 'pay-001',
  'bidId': 'bid-001',
  'clientSecret': 'pi_secret',
  'amount': 120.0,
  'commissionAmount': 14.4,
  'status': 'REQUIRES_PAYMENT_METHOD',
};

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late PaymentRemoteDatasource datasource;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    datasource = PaymentRemoteDatasource(mockClient);
  });

  // ── ConnectAccountModel.fromJson ─────────────────────────────────────────────

  group('ConnectAccountModel.fromJson', () {
    test('parses stripeAccountId and stripeOnboarded=true', () {
      // ignore: prefer_const_constructors
      final m = ConnectAccountModel.fromJson(_connectJson);
      expect(m.stripeAccountId, 'acct_123');
      expect(m.stripeOnboarded, isTrue);
    });

    test('defaults stripeOnboarded to false when absent', () {
      // ignore: prefer_const_constructors
      final m = ConnectAccountModel.fromJson({'stripeAccountId': 'acct_x'});
      expect(m.stripeOnboarded, isFalse);
    });
  });

  // ── PaymentModel ─────────────────────────────────────────────────────────────

  group('PaymentModel.fromJson / toJson', () {
    test('fromJson parses all fields', () {
      final m = PaymentModel.fromJson(_paymentJson);
      expect(m.id, 'pay-001');
      expect(m.bidId, 'bid-001');
      expect(m.clientSecret, 'pi_secret');
      expect(m.amount, 120.0);
      expect(m.commissionAmount, 14.4);
      expect(m.status, 'REQUIRES_PAYMENT_METHOD');
    });

    test('fromJson with null clientSecret', () {
      final m = PaymentModel.fromJson({..._paymentJson, 'clientSecret': null});
      expect(m.clientSecret, isNull);
    });

    test('fromJson with missing clientSecret', () {
      final json = Map<String, dynamic>.from(_paymentJson)
        ..remove('clientSecret');
      final m = PaymentModel.fromJson(json);
      expect(m.clientSecret, isNull);
    });

    test('toJson round-trips correctly', () {
      final m = PaymentModel.fromJson(_paymentJson);
      final json = m.toJson();
      expect(json['id'], 'pay-001');
      expect(json['status'], 'REQUIRES_PAYMENT_METHOD');
    });

    test('int amounts coerce to double', () {
      final m = PaymentModel.fromJson({..._paymentJson, 'amount': 100, 'commissionAmount': 12});
      expect(m.amount, 100.0);
      expect(m.commissionAmount, 12.0);
    });
  });

  // ── createConnectAccount ──────────────────────────────────────────────────────

  group('createConnectAccount', () {
    test('returns ConnectAccountModel on success', () async {
      when(() => mockDio.post('/payments/connect/account'))
          .thenAnswer((_) async => _ok(_connectJson, '/payments/connect/account'));

      final result = await datasource.createConnectAccount();

      expect(result.stripeAccountId, 'acct_123');
      expect(result.stripeOnboarded, isTrue);
    });
  });

  // ── createOnboardingLink ──────────────────────────────────────────────────────

  group('createOnboardingLink', () {
    test('returns url string', () async {
      when(() => mockDio.post('/payments/connect/onboarding-link'))
          .thenAnswer((_) async => _ok(
              {'url': 'https://connect.stripe.com/setup/e/abc'},
              '/payments/connect/onboarding-link'));

      final url = await datasource.createOnboardingLink();

      expect(url, startsWith('https://connect.stripe.com'));
    });
  });

  // ── createPayment ─────────────────────────────────────────────────────────────

  group('createPayment', () {
    test('returns PaymentModel on success', () async {
      when(() => mockDio.post('/payments', data: any(named: 'data')))
          .thenAnswer((_) async => _ok(_paymentJson, '/payments'));

      final result = await datasource.createPayment('bid-001');

      expect(result.id, 'pay-001');
      expect(result.status, 'REQUIRES_PAYMENT_METHOD');
    });
  });

  // ── getPaymentForBid ──────────────────────────────────────────────────────────

  group('getPaymentForBid', () {
    test('returns PaymentModel when found', () async {
      when(() => mockDio.get('/payments/bid/bid-001'))
          .thenAnswer((_) async => _ok(_paymentJson, '/payments/bid/bid-001'));

      final result = await datasource.getPaymentForBid('bid-001');

      expect(result, isNotNull);
      expect(result!.bidId, 'bid-001');
    });

    test('returns null on 404', () async {
      when(() => mockDio.get('/payments/bid/bid-999')).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/payments/bid/bid-999'),
        response: Response(
          requestOptions: RequestOptions(path: '/payments/bid/bid-999'),
          statusCode: 404,
        ),
      ));

      final result = await datasource.getPaymentForBid('bid-999');

      expect(result, isNull);
    });

    test('rethrows DioException when not 404', () async {
      when(() => mockDio.get('/payments/bid/bid-err')).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/payments/bid/bid-err'),
        response: Response(
          requestOptions: RequestOptions(path: '/payments/bid/bid-err'),
          statusCode: 500,
        ),
      ));

      expect(
        () => datasource.getPaymentForBid('bid-err'),
        throwsA(isA<DioException>()),
      );
    });
  });
}
