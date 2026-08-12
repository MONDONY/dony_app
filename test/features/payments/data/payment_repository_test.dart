import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:dony/features/payments/data/models/connect_account_model.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/models/ephemeral_key_model.dart';
import 'package:dony/features/payments/data/models/payment_status.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPaymentRemoteDatasource extends Mock
    implements PaymentRemoteDatasource {}

void main() {
  late MockPaymentRemoteDatasource mockDs;
  late PaymentRepository repo;

  setUp(() {
    mockDs = MockPaymentRemoteDatasource();
    repo = PaymentRepository(mockDs);
  });

  const account = ConnectAccountModel(
    stripeAccountId: 'acct_test',
    stripeOnboarded: false,
  );

  const payment = PaymentModel(
    id: 'pay-1',
    bidId: 'bid-1',
    clientSecret: 'pi_secret',
    amount: 120.0,
    commissionAmount: 14.4,
    status: PaymentStatus.pending,
  );

  // ── createConnectAccount ─────────────────────────────────────────────────────

  group('createConnectAccount', () {
    test('returns result from datasource on success', () async {
      when(
        () => mockDs.createConnectAccount(),
      ).thenAnswer((_) async => account);
      final result = await repo.createConnectAccount();
      expect(result.stripeAccountId, 'acct_test');
    });

    test('rethrows AppException as-is', () async {
      when(
        () => mockDs.createConnectAccount(),
      ).thenThrow(const NetworkException('timeout'));
      expect(
        () => repo.createConnectAccount(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('wraps generic exception in NetworkException', () async {
      when(
        () => mockDs.createConnectAccount(),
      ).thenThrow(Exception('generic error'));
      expect(
        () => repo.createConnectAccount(),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ── createOnboardingLink ─────────────────────────────────────────────────────

  group('createOnboardingLink', () {
    test('returns URL from datasource', () async {
      when(
        () => mockDs.createOnboardingLink(),
      ).thenAnswer((_) async => 'https://connect.stripe.com/setup');
      final url = await repo.createOnboardingLink();
      expect(url, contains('stripe.com'));
    });

    test('rethrows AppException', () async {
      when(
        () => mockDs.createOnboardingLink(),
      ).thenThrow(const ServerException('503'));
      expect(
        () => repo.createOnboardingLink(),
        throwsA(isA<ServerException>()),
      );
    });

    test('wraps generic exception in NetworkException', () async {
      when(
        () => mockDs.createOnboardingLink(),
      ).thenThrow(Exception('DNS failure'));
      expect(
        () => repo.createOnboardingLink(),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ── createPayment ────────────────────────────────────────────────────────────

  group('createPayment', () {
    test('returns PaymentModel from datasource', () async {
      when(
        () => mockDs.createPayment('bid-1'),
      ).thenAnswer((_) async => payment);
      final result = await repo.createPayment('bid-1');
      expect(result.id, 'pay-1');
    });

    test('rethrows ValidationException', () async {
      when(
        () => mockDs.createPayment(any()),
      ).thenThrow(const ValidationException('Invalid bid'));
      expect(
        () => repo.createPayment('bid-x'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('wraps Exception in NetworkException', () async {
      when(
        () => mockDs.createPayment(any()),
      ).thenThrow(Exception('Stripe unreachable'));
      expect(
        () => repo.createPayment('bid-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ── getPaymentForBid ─────────────────────────────────────────────────────────

  group('getPaymentForBid', () {
    test('returns PaymentModel when found', () async {
      when(
        () => mockDs.getPaymentForBid('bid-1'),
      ).thenAnswer((_) async => payment);
      final result = await repo.getPaymentForBid('bid-1');
      expect(result?.bidId, 'bid-1');
    });

    test('returns null when datasource returns null', () async {
      when(() => mockDs.getPaymentForBid(any())).thenAnswer((_) async => null);
      final result = await repo.getPaymentForBid('bid-x');
      expect(result, isNull);
    });

    test('wraps Exception in NetworkException', () async {
      when(
        () => mockDs.getPaymentForBid(any()),
      ).thenThrow(Exception('network error'));
      expect(
        () => repo.getPaymentForBid('bid-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ── createEphemeralKey ───────────────────────────────────────────────────────

  group('createEphemeralKey', () {
    const key = EphemeralKeyModel(
      ephemeralKeySecret: 'ek_test_secret',
      customerId: 'cus_123',
    );

    test('returns key from datasource', () async {
      when(() => mockDs.createEphemeralKey()).thenAnswer((_) async => key);
      final result = await repo.createEphemeralKey();
      expect(result, key);
    });

    test('wraps Exception in NetworkException', () async {
      when(
        () => mockDs.createEphemeralKey(),
      ).thenThrow(Exception('network error'));
      expect(() => repo.createEphemeralKey(), throwsA(isA<NetworkException>()));
    });
  });
}
