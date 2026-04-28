import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/data/models/connect_account_model.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPaymentRepository extends Mock implements PaymentRepository {}

void main() {
  late MockPaymentRepository mockRepo;

  setUp(() {
    mockRepo = MockPaymentRepository();
  });

  PaymentBloc buildBloc() => PaymentBloc(mockRepo);

  // ── PaymentConnectAccountRequested ──────────────────────────────────────────

  group('PaymentConnectAccountRequested', () {
    blocTest<PaymentBloc, PaymentState>(
      'emits [Loading, OnboardingUrlReady] when not yet onboarded',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createConnectAccount()).thenAnswer(
          (_) async => const ConnectAccountModel(
            stripeAccountId: 'acct_test',
            stripeOnboarded: false,
          ),
        );
        when(() => mockRepo.createOnboardingLink())
            .thenAnswer((_) async => 'https://connect.stripe.com/setup');
      },
      act: (b) => b.add(const PaymentConnectAccountRequested()),
      expect: () => [
        const PaymentLoading(),
        isA<PaymentOnboardingUrlReady>().having(
          (s) => s.url,
          'url',
          'https://connect.stripe.com/setup',
        ),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      'emits [Loading, OnboardingComplete] when already onboarded',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createConnectAccount()).thenAnswer(
          (_) async => const ConnectAccountModel(
            stripeAccountId: 'acct_test',
            stripeOnboarded: true,
          ),
        );
      },
      act: (b) => b.add(const PaymentConnectAccountRequested()),
      expect: () => [
        const PaymentLoading(),
        const PaymentOnboardingComplete(),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      'emits [Loading, PaymentError] when createConnectAccount throws',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createConnectAccount())
            .thenThrow(Exception('network error'));
      },
      act: (b) => b.add(const PaymentConnectAccountRequested()),
      expect: () => [
        const PaymentLoading(),
        isA<PaymentError>(),
      ],
    );
  });

  // ── PaymentOnboardingStatusChecked ──────────────────────────────────────────

  group('PaymentOnboardingStatusChecked', () {
    blocTest<PaymentBloc, PaymentState>(
      'emits [Loading, OnboardingComplete] when onboarded',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createConnectAccount()).thenAnswer(
          (_) async => const ConnectAccountModel(
            stripeAccountId: 'acct_1',
            stripeOnboarded: true,
          ),
        );
      },
      act: (b) => b.add(const PaymentOnboardingStatusChecked()),
      expect: () => [
        const PaymentLoading(),
        const PaymentOnboardingComplete(),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      'emits [Loading, OnboardingPending] when not yet onboarded',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createConnectAccount()).thenAnswer(
          (_) async => const ConnectAccountModel(
            stripeAccountId: 'acct_1',
            stripeOnboarded: false,
          ),
        );
      },
      act: (b) => b.add(const PaymentOnboardingStatusChecked()),
      expect: () => [
        const PaymentLoading(),
        const PaymentOnboardingPending(),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      'emits [Loading, PaymentError] when generic exception thrown',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createConnectAccount())
            .thenThrow(Exception('network error'));
      },
      act: (b) => b.add(const PaymentOnboardingStatusChecked()),
      expect: () => [
        const PaymentLoading(),
        isA<PaymentError>(),
      ],
    );
  });

  // ── PaymentInitiated ────────────────────────────────────────────────────────

  group('PaymentInitiated', () {
    blocTest<PaymentBloc, PaymentState>(
      'emits [Loading, SheetReady] when payment created successfully',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createPayment('bid-1')).thenAnswer(
          (_) async => const PaymentModel(
            id: 'pay-1',
            bidId: 'bid-1',
            clientSecret: 'pi_test_secret',
            amount: 120.0,
            commissionAmount: 14.4,
            status: 'REQUIRES_PAYMENT_METHOD',
          ),
        );
      },
      act: (b) => b.add(const PaymentInitiated('bid-1')),
      expect: () => [
        const PaymentLoading(),
        isA<PaymentSheetReady>()
            .having((s) => s.amount, 'amount', 120.0)
            .having((s) => s.clientSecret, 'clientSecret', 'pi_test_secret'),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      'emits [Loading, PaymentError] when clientSecret is null',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createPayment('bid-1')).thenAnswer(
          (_) async => const PaymentModel(
            id: 'pay-1',
            bidId: 'bid-1',
            clientSecret: null,
            amount: 120.0,
            commissionAmount: 14.4,
            status: 'ALREADY_PAID',
          ),
        );
      },
      act: (b) => b.add(const PaymentInitiated('bid-1')),
      expect: () => [
        const PaymentLoading(),
        isA<PaymentError>(),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      'emits [Loading, PaymentError] when createPayment throws',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createPayment(any()))
            .thenThrow(Exception('Stripe error'));
      },
      act: (b) => b.add(const PaymentInitiated('bid-x')),
      expect: () => [
        const PaymentLoading(),
        isA<PaymentError>(),
      ],
    );
  });

  // ── PaymentSheetCompleted ───────────────────────────────────────────────────

  group('PaymentSheetCompleted', () {
    blocTest<PaymentBloc, PaymentState>(
      'emits EscrowPending with amount from SheetReady state',
      build: buildBloc,
      seed: () => const PaymentSheetReady(
        clientSecret: 'pi_secret',
        amount: 99.0,
        commissionAmount: 11.88,
        paymentId: 'pay-2',
      ),
      act: (b) => b.add(const PaymentSheetCompleted()),
      expect: () => [
        isA<PaymentEscrowPending>().having((s) => s.amount, 'amount', 99.0),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      'does nothing when state is not SheetReady',
      build: buildBloc,
      act: (b) => b.add(const PaymentSheetCompleted()),
      expect: () => [],
    );
  });

  // ── PaymentFailed ───────────────────────────────────────────────────────────

  group('PaymentFailed', () {
    blocTest<PaymentBloc, PaymentState>(
      'emits PaymentError with message',
      build: buildBloc,
      act: (b) => b.add(const PaymentFailed('Card declined')),
      expect: () => [
        isA<PaymentError>().having((s) => s.message, 'message', 'Card declined'),
      ],
    );
  });

  // ── State equality ──────────────────────────────────────────────────────────

  group('State props', () {
    test('PaymentSheetReady props include all fields', () {
      const s = PaymentSheetReady(
        clientSecret: 'cs',
        amount: 50.0,
        commissionAmount: 6.0,
        paymentId: 'p1',
      );
      expect(s.props, ['cs', 50.0, 6.0, 'p1']);
    });

    test('PaymentEscrowPending props include amount', () {
      const s = PaymentEscrowPending(75.0);
      expect(s.props, [75.0]);
    });

    test('PaymentError props include message', () {
      const s = PaymentError('oops');
      expect(s.props, ['oops']);
    });
  });
}
