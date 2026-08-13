import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/data/stripe_account_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStripeAccountRepository extends Mock
    implements IStripeAccountRepository {}

const _complete = ConnectAccountStatus(status: 'ONBOARDING_COMPLETE');
const _disabled = ConnectAccountStatus(status: 'DISABLED');
const _rejected = ConnectAccountStatus(
  status: 'REJECTED',
  reason: 'Docs invalides',
);

void main() {
  late MockStripeAccountRepository mockRepo;

  setUp(() {
    mockRepo = MockStripeAccountRepository();
  });

  StripeAccountBloc buildBloc() => StripeAccountBloc(mockRepo);

  group('StripeAccountBloc — initial state', () {
    test('initial state is StripeAccountInitial', () {
      expect(buildBloc().state, isA<StripeAccountInitial>());
    });
  });

  group('StripeAccountStatusLoaded', () {
    blocTest<StripeAccountBloc, StripeAccountState>(
      'emits [Loading, Ready(complete)] on success',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getAccountStatus(),
        ).thenAnswer((_) async => _complete);
      },
      act: (b) => b.add(const StripeAccountStatusLoaded()),
      expect: () => [
        isA<StripeAccountLoading>(),
        isA<StripeAccountReady>().having(
          (s) => s.accountStatus.isComplete,
          'isComplete',
          isTrue,
        ),
      ],
    );

    blocTest<StripeAccountBloc, StripeAccountState>(
      'emits [Loading, Ready(disabled)] when account is DISABLED',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getAccountStatus(),
        ).thenAnswer((_) async => _disabled);
      },
      act: (b) => b.add(const StripeAccountStatusLoaded()),
      expect: () => [
        isA<StripeAccountLoading>(),
        isA<StripeAccountReady>().having(
          (s) => s.accountStatus.isDisabled,
          'isDisabled',
          isTrue,
        ),
      ],
    );

    blocTest<StripeAccountBloc, StripeAccountState>(
      'emits [Loading, Ready(rejected)] when account is REJECTED',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getAccountStatus(),
        ).thenAnswer((_) async => _rejected);
      },
      act: (b) => b.add(const StripeAccountStatusLoaded()),
      expect: () => [
        isA<StripeAccountLoading>(),
        isA<StripeAccountReady>().having(
          (s) => s.accountStatus.isRejected,
          'isRejected',
          isTrue,
        ),
      ],
    );

    blocTest<StripeAccountBloc, StripeAccountState>(
      'emits [Loading, LoadError] when repo throws',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getAccountStatus(),
        ).thenThrow(Exception('Network error'));
      },
      act: (b) => b.add(const StripeAccountStatusLoaded()),
      expect: () => [
        isA<StripeAccountLoading>(),
        isA<StripeAccountLoadError>(),
      ],
    );
  });

  group('StripeAccountStatusRefreshed', () {
    blocTest<StripeAccountBloc, StripeAccountState>(
      'emits [Ready(complete)] without Loading on refresh',
      build: buildBloc,
      seed: () => const StripeAccountReady(_disabled),
      setUp: () {
        when(
          () => mockRepo.getAccountStatus(),
        ).thenAnswer((_) async => _complete);
      },
      act: (b) => b.add(const StripeAccountStatusRefreshed()),
      expect: () => [
        isA<StripeAccountReady>().having(
          (s) => s.accountStatus.isComplete,
          'isComplete',
          isTrue,
        ),
      ],
    );

    blocTest<StripeAccountBloc, StripeAccountState>(
      'emits [LoadError] silently on refresh failure',
      build: buildBloc,
      seed: () => const StripeAccountReady(_complete),
      setUp: () {
        when(() => mockRepo.getAccountStatus()).thenThrow(Exception('Timeout'));
      },
      act: (b) => b.add(const StripeAccountStatusRefreshed()),
      expect: () => [isA<StripeAccountLoadError>()],
    );
  });
}
