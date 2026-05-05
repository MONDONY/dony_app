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
        when(() => mockRepo.getAccountStatus())
            .thenAnswer((_) async => _complete);
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
        when(() => mockRepo.getAccountStatus())
            .thenAnswer((_) async => _notCreated);
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
        when(() => mockRepo.getAccountStatus())
            .thenAnswer((_) async => _pending);
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
        when(() => mockRepo.getAccountStatus())
            .thenThrow(Exception('Network error'));
      },
      act: (b) => b.add(const ConnectOnboardingStatusRequested()),
      expect: () => [
        isA<ConnectOnboardingLoading>(),
        isA<ConnectOnboardingError>(),
      ],
    );
  });

  // ── Link requested ──────────────────────────────────────────────────────────

  group('ConnectOnboardingLinkRequested', () {
    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Loading, UrlReady] with url on success',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.createOnboardingLink())
            .thenAnswer((_) async => 'https://connect.stripe.com/setup/abc');
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
        when(() => mockRepo.createOnboardingLink())
            .thenThrow(Exception('Stripe error'));
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
        when(() => mockRepo.getAccountStatus())
            .thenAnswer((_) async => _complete);
      },
      act: (b) => b.add(const ConnectOnboardingPollingRequested()),
      expect: () => [isA<ConnectOnboardingComplete>()],
    );

    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Pending] when account is still pending during polling',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getAccountStatus())
            .thenAnswer((_) async => _pending);
      },
      act: (b) => b.add(const ConnectOnboardingPollingRequested()),
      expect: () => [isA<ConnectOnboardingPending>()],
    );

    blocTest<ConnectOnboardingBloc, ConnectOnboardingState>(
      'emits [Error] when polling throws',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getAccountStatus())
            .thenThrow(Exception('Timeout'));
      },
      act: (b) => b.add(const ConnectOnboardingPollingRequested()),
      expect: () => [isA<ConnectOnboardingError>()],
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
