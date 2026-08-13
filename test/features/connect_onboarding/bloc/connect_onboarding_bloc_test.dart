import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectOnboardingRepository extends Mock
    implements IConnectOnboardingRepository {}

const _notCreated = ConnectAccountStatus(status: 'NOT_CREATED');
const _pending = ConnectAccountStatus(status: 'PENDING_ONBOARDING');
const _complete = ConnectAccountStatus(status: 'ONBOARDING_COMPLETE');
const _disabled = ConnectAccountStatus(status: 'DISABLED');
const _rejected = ConnectAccountStatus(
  status: 'REJECTED',
  reason: 'Docs invalides',
);

void main() {
  late MockConnectOnboardingRepository mockRepo;

  setUp(() {
    mockRepo = MockConnectOnboardingRepository();
  });

  ConnectOnboardingBloc buildBloc() => ConnectOnboardingBloc(mockRepo);

  group('ConnectOnboardingBloc — initial state', () {
    test('initial state is ConnectOnboardingInitial', () {
      expect(buildBloc().state, isA<ConnectOnboardingInitial>());
    });
  });

  // ── Status requested ────────────────────────────────────────────────────────

  group('ConnectOnboardingStatusRequested', () {
    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Loading, Complete] when status is ONBOARDING_COMPLETE',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getAccountStatus(),
        ).thenAnswer((_) async => _complete);
      },
      act: (b) => b.add(const ConnectOnboardingStatusRequested()),
      expect: () => [
        isA<ConnectOnboardingLoading>(),
        isA<ConnectOnboardingComplete>(),
      ],
    );

    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Loading, NeedsOnboarding] when status is NOT_CREATED',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getAccountStatus(),
        ).thenAnswer((_) async => _notCreated);
      },
      act: (b) => b.add(const ConnectOnboardingStatusRequested()),
      expect: () => [
        isA<ConnectOnboardingLoading>(),
        isA<ConnectOnboardingNeedsOnboarding>(),
      ],
    );

    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Loading, NeedsOnboarding] when status is PENDING_ONBOARDING',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getAccountStatus(),
        ).thenAnswer((_) async => _pending);
      },
      act: (b) => b.add(const ConnectOnboardingStatusRequested()),
      expect: () => [
        isA<ConnectOnboardingLoading>(),
        isA<ConnectOnboardingNeedsOnboarding>(),
      ],
    );

    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Loading, Error] when getAccountStatus throws',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getAccountStatus(),
        ).thenThrow(Exception('Network error'));
      },
      act: (b) => b.add(const ConnectOnboardingStatusRequested()),
      expect: () => [
        isA<ConnectOnboardingLoading>(),
        isA<ConnectOnboardingError>(),
      ],
    );

    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Loading, Disabled] when status is DISABLED',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getAccountStatus(),
        ).thenAnswer((_) async => _disabled);
      },
      act: (b) => b.add(const ConnectOnboardingStatusRequested()),
      expect: () => [
        isA<ConnectOnboardingLoading>(),
        isA<ConnectOnboardingDisabled>(),
      ],
    );

    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Loading, Rejected] with reason when status is REJECTED',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getAccountStatus(),
        ).thenAnswer((_) async => _rejected);
      },
      act: (b) => b.add(const ConnectOnboardingStatusRequested()),
      expect: () => [
        isA<ConnectOnboardingLoading>(),
        isA<ConnectOnboardingRejected>().having(
          (s) => s.reason,
          'reason',
          'Docs invalides',
        ),
      ],
    );
  });

  // ── Link requested ──────────────────────────────────────────────────────────

  group('ConnectOnboardingLinkRequested', () {
    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Loading, UrlReady] with url on success',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.createOnboardingLink(),
        ).thenAnswer((_) async => 'https://connect.stripe.com/setup/abc');
      },
      act: (b) => b.add(const ConnectOnboardingLinkRequested()),
      expect: () => [
        isA<ConnectOnboardingLoading>(),
        isA<ConnectOnboardingUrlReady>().having(
          (s) => s.url,
          'url',
          'https://connect.stripe.com/setup/abc',
        ),
      ],
    );

    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Loading, Error] when createOnboardingLink throws',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.createOnboardingLink(),
        ).thenThrow(Exception('Stripe error'));
      },
      act: (b) => b.add(const ConnectOnboardingLinkRequested()),
      expect: () => [
        isA<ConnectOnboardingLoading>(),
        isA<ConnectOnboardingError>(),
      ],
    );
  });

  // ── Polling requested ───────────────────────────────────────────────────────

  group('ConnectOnboardingPollingRequested', () {
    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Complete] when account is complete during polling',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getAccountStatus(),
        ).thenAnswer((_) async => _complete);
      },
      act: (b) => b.add(const ConnectOnboardingPollingRequested()),
      expect: () => [isA<ConnectOnboardingComplete>()],
    );

    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Pending] when account is still pending during polling',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getAccountStatus(),
        ).thenAnswer((_) async => _pending);
      },
      act: (b) => b.add(const ConnectOnboardingPollingRequested()),
      expect: () => [isA<ConnectOnboardingPending>()],
    );

    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Disabled] when account is DISABLED during polling',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getAccountStatus(),
        ).thenAnswer((_) async => _disabled);
      },
      act: (b) => b.add(const ConnectOnboardingPollingRequested()),
      expect: () => [isA<ConnectOnboardingDisabled>()],
    );

    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Rejected] with reason when account is REJECTED during polling',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getAccountStatus(),
        ).thenAnswer((_) async => _rejected);
      },
      act: (b) => b.add(const ConnectOnboardingPollingRequested()),
      expect: () => [
        isA<ConnectOnboardingRejected>().having(
          (s) => s.reason,
          'reason',
          'Docs invalides',
        ),
      ],
    );

    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Error] when polling throws',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getAccountStatus()).thenThrow(Exception('Timeout'));
      },
      act: (b) => b.add(const ConnectOnboardingPollingRequested()),
      expect: () => [isA<ConnectOnboardingError>()],
    );
  });

  // ── Launch failed ───────────────────────────────────────────────────────────

  group('ConnectOnboardingLaunchFailed', () {
    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Error] with provided message',
      build: buildBloc,
      act: (b) => b.add(
        const ConnectOnboardingLaunchFailed(
          "Impossible d'ouvrir le navigateur.",
        ),
      ),
      expect: () => [
        isA<ConnectOnboardingError>().having(
          (s) => s.error.message,
          'message',
          "Impossible d'ouvrir le navigateur.",
        ),
      ],
    );
  });

  // ── ConnectAccountStatus helpers ────────────────────────────────────────────

  group('ConnectAccountStatus', () {
    test('isComplete returns true for ONBOARDING_COMPLETE', () {
      expect(_complete.isComplete, isTrue);
    });

    test('isComplete returns false for PENDING_ONBOARDING', () {
      expect(_pending.isComplete, isFalse);
    });

    test('needsOnboarding returns true for NOT_CREATED', () {
      expect(_notCreated.needsOnboarding, isTrue);
    });

    test('needsOnboarding returns true for PENDING_ONBOARDING', () {
      expect(_pending.needsOnboarding, isTrue);
    });

    test('needsOnboarding returns false for ONBOARDING_COMPLETE', () {
      expect(_complete.needsOnboarding, isFalse);
    });
  });
}
