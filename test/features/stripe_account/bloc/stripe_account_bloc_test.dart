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
      'resynchronise depuis Stripe plutôt que de relire le statut stocké',
      build: buildBloc,
      seed: () => const StripeAccountReady(_disabled),
      setUp: () {
        // Le statut stocké est encore périmé (webhook manqué) : seule la
        // resynchronisation apprend que le compte est devenu utilisable.
        when(
          () => mockRepo.refreshAccountStatus(),
        ).thenAnswer((_) async => _complete);
        when(
          () => mockRepo.getAccountStatus(),
        ).thenAnswer((_) async => _disabled);
      },
      act: (b) => b.add(const StripeAccountStatusRefreshed()),
      expect: () => [
        isA<StripeAccountReady>().having(
          (s) => s.accountStatus.isComplete,
          'isComplete',
          isTrue,
        ),
      ],
      verify: (_) {
        verify(() => mockRepo.refreshAccountStatus()).called(1);
        verifyNever(() => mockRepo.getAccountStatus());
      },
    );

    blocTest<StripeAccountBloc, StripeAccountState>(
      'retombe sur le statut stocké quand la resynchronisation échoue',
      build: buildBloc,
      seed: () => const StripeAccountReady(_disabled),
      setUp: () {
        // Cas courant : aucun compte Stripe encore créé (409), réseau coupé,
        // ou Stripe indisponible. Afficher une erreur ici serait une
        // régression — un simple retour au premier plan la déclencherait.
        when(
          () => mockRepo.refreshAccountStatus(),
        ).thenThrow(Exception('stripe-account-required'));
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
      verify: (_) => verify(() => mockRepo.getAccountStatus()).called(1),
    );

    blocTest<StripeAccountBloc, StripeAccountState>(
      'emits [LoadError] quand la resynchronisation ET la relecture échouent',
      build: buildBloc,
      seed: () => const StripeAccountReady(_complete),
      setUp: () {
        when(
          () => mockRepo.refreshAccountStatus(),
        ).thenThrow(Exception('Timeout'));
        when(() => mockRepo.getAccountStatus()).thenThrow(Exception('Timeout'));
      },
      act: (b) => b.add(const StripeAccountStatusRefreshed()),
      expect: () => [isA<StripeAccountLoadError>()],
    );
  });
}
