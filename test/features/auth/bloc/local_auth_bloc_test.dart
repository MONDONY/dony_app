import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/local_auth_bloc.dart';
import 'package:dony/features/auth/bloc/local_auth_event.dart';
import 'package:dony/features/auth/bloc/local_auth_state.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalAuthService extends Mock implements LocalAuthService {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockLocalAuthService mockService;
  late MockFlutterSecureStorage mockStorage;

  setUp(() {
    mockService = MockLocalAuthService();
    mockStorage = MockFlutterSecureStorage();

    // Default: no lockout, full attempts.
    when(() => mockStorage.read(key: 'pin_lockout_until'))
        .thenAnswer((_) async => null);
    when(() => mockStorage.read(key: 'pin_attempts_left'))
        .thenAnswer((_) async => '3');
    when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});
    when(() => mockStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});
  });

  LocalAuthBloc buildBloc() =>
      LocalAuthBloc(mockService, secureStorage: mockStorage);

  // ── LocalAuthStarted ────────────────────────────────────────────────────────

  group('LocalAuthStarted — no PIN set', () {
    blocTest<LocalAuthBloc, LocalAuthState>(
      'emits [Checking, NoPinSet] when no PIN is configured',
      build: buildBloc,
      setUp: () {
        when(() => mockService.isPinSet()).thenAnswer((_) async => false);
      },
      act: (b) => b.add(const LocalAuthStarted()),
      expect: () => [
        const LocalAuthChecking(),
        const LocalAuthNoPinSet(),
      ],
    );
  });

  group('LocalAuthStarted — biometric success', () {
    blocTest<LocalAuthBloc, LocalAuthState>(
      'emits [Checking, Success] when biometric is available and succeeds',
      build: buildBloc,
      setUp: () {
        when(() => mockService.isPinSet()).thenAnswer((_) async => true);
        when(() => mockService.isBiometricAvailable())
            .thenAnswer((_) async => true);
        when(() => mockService.authenticateWithBiometric())
            .thenAnswer((_) async => true);
      },
      act: (b) => b.add(const LocalAuthStarted()),
      expect: () => [
        const LocalAuthChecking(),
        const LocalAuthSuccess(),
      ],
    );
  });

  group('LocalAuthStarted — biometric fails → PIN required', () {
    blocTest<LocalAuthBloc, LocalAuthState>(
      'emits [Checking, PinRequired] when biometric fails',
      build: buildBloc,
      setUp: () {
        when(() => mockService.isPinSet()).thenAnswer((_) async => true);
        when(() => mockService.isBiometricAvailable())
            .thenAnswer((_) async => true);
        when(() => mockService.authenticateWithBiometric())
            .thenAnswer((_) async => false);
      },
      act: (b) => b.add(const LocalAuthStarted()),
      expect: () => [
        const LocalAuthChecking(),
        isA<LocalAuthPinRequired>()
            .having((s) => s.attemptsLeft, 'attemptsLeft', 3)
            .having((s) => s.biometricAvailable, 'biometricAvailable', true),
      ],
    );
  });

  group('LocalAuthStarted — no biometric → PIN required', () {
    blocTest<LocalAuthBloc, LocalAuthState>(
      'emits [Checking, PinRequired] when biometric not available',
      build: buildBloc,
      setUp: () {
        when(() => mockService.isPinSet()).thenAnswer((_) async => true);
        when(() => mockService.isBiometricAvailable())
            .thenAnswer((_) async => false);
      },
      act: (b) => b.add(const LocalAuthStarted()),
      expect: () => [
        const LocalAuthChecking(),
        isA<LocalAuthPinRequired>()
            .having((s) => s.biometricAvailable, 'biometricAvailable', false),
      ],
    );
  });

  group('LocalAuthStarted — lockout persisted across sessions', () {
    blocTest<LocalAuthBloc, LocalAuthState>(
      'emits [Checking, Locked] when lockout is still active from a previous session',
      build: buildBloc,
      setUp: () {
        final future = DateTime.now().add(const Duration(seconds: 25));
        when(() => mockStorage.read(key: 'pin_lockout_until'))
            .thenAnswer((_) async => future.toIso8601String());
      },
      act: (b) => b.add(const LocalAuthStarted()),
      expect: () => [
        const LocalAuthChecking(),
        isA<LocalAuthLocked>()
            .having((s) => s.secondsLeft, 'secondsLeft', greaterThan(0)),
      ],
    );
  });

  // ── LocalAuthBiometricRequested ─────────────────────────────────────────────

  group('LocalAuthBiometricRequested', () {
    blocTest<LocalAuthBloc, LocalAuthState>(
      'emits [Success] when biometric succeeds',
      build: buildBloc,
      setUp: () {
        when(() => mockService.authenticateWithBiometric())
            .thenAnswer((_) async => true);
      },
      act: (b) => b.add(const LocalAuthBiometricRequested()),
      expect: () => [const LocalAuthSuccess()],
    );

    blocTest<LocalAuthBloc, LocalAuthState>(
      'emits nothing when biometric fails',
      build: buildBloc,
      setUp: () {
        when(() => mockService.authenticateWithBiometric())
            .thenAnswer((_) async => false);
      },
      act: (b) => b.add(const LocalAuthBiometricRequested()),
      expect: () => [],
    );
  });

  // ── LocalAuthPinSubmitted ───────────────────────────────────────────────────

  group('LocalAuthPinSubmitted', () {
    blocTest<LocalAuthBloc, LocalAuthState>(
      'emits [Success] when PIN is correct',
      build: buildBloc,
      setUp: () {
        when(() => mockService.validatePin('1234'))
            .thenAnswer((_) async => true);
      },
      act: (b) => b.add(const LocalAuthPinSubmitted('1234')),
      expect: () => [const LocalAuthSuccess()],
    );

    blocTest<LocalAuthBloc, LocalAuthState>(
      'emits [PinRequired with attemptsLeft=2] when PIN is wrong once',
      build: buildBloc,
      setUp: () {
        when(() => mockService.validatePin(any()))
            .thenAnswer((_) async => false);
        when(() => mockService.isBiometricAvailable())
            .thenAnswer((_) async => false);
      },
      act: (b) => b.add(const LocalAuthPinSubmitted('0000')),
      expect: () => [
        isA<LocalAuthPinRequired>()
            .having((s) => s.attemptsLeft, 'attemptsLeft', 2),
      ],
    );

    blocTest<LocalAuthBloc, LocalAuthState>(
      'emits [Locked] when PIN is wrong 3 times',
      build: buildBloc,
      setUp: () {
        when(() => mockService.validatePin(any()))
            .thenAnswer((_) async => false);
        when(() => mockService.isBiometricAvailable())
            .thenAnswer((_) async => false);
      },
      act: (b) async {
        b.add(const LocalAuthPinSubmitted('0000'));
        await Future.delayed(const Duration(milliseconds: 50));
        b.add(const LocalAuthPinSubmitted('0000'));
        await Future.delayed(const Duration(milliseconds: 50));
        b.add(const LocalAuthPinSubmitted('0000'));
      },
      expect: () => [
        isA<LocalAuthPinRequired>().having((s) => s.attemptsLeft, 'attemptsLeft', 2),
        isA<LocalAuthPinRequired>().having((s) => s.attemptsLeft, 'attemptsLeft', 1),
        isA<LocalAuthLocked>().having((s) => s.secondsLeft, 'secondsLeft', 30),
      ],
    );

    blocTest<LocalAuthBloc, LocalAuthState>(
      'persists lockout timestamp when PIN is wrong 3 times',
      build: buildBloc,
      setUp: () {
        when(() => mockService.validatePin(any()))
            .thenAnswer((_) async => false);
        when(() => mockService.isBiometricAvailable())
            .thenAnswer((_) async => false);
      },
      act: (b) async {
        b.add(const LocalAuthPinSubmitted('0000'));
        await Future.delayed(const Duration(milliseconds: 50));
        b.add(const LocalAuthPinSubmitted('0000'));
        await Future.delayed(const Duration(milliseconds: 50));
        b.add(const LocalAuthPinSubmitted('0000'));
        await Future.delayed(const Duration(milliseconds: 50));
      },
      verify: (_) {
        verify(() => mockStorage.write(
              key: 'pin_lockout_until',
              value: any(named: 'value'),
            )).called(1);
        verify(() => mockStorage.write(
              key: 'pin_attempts_left',
              value: '0',
            )).called(1);
      },
    );
  });

  // ── LocalAuthLockExpired ────────────────────────────────────────────────────

  group('LocalAuthLockExpired', () {
    blocTest<LocalAuthBloc, LocalAuthState>(
      'emits [PinRequired with 3 attempts] when lock expires',
      build: buildBloc,
      act: (b) => b.add(const LocalAuthLockExpired()),
      expect: () => [
        isA<LocalAuthPinRequired>()
            .having((s) => s.attemptsLeft, 'attemptsLeft', 3),
      ],
    );

    blocTest<LocalAuthBloc, LocalAuthState>(
      'resets and persists attempts to 3 when lock expires',
      build: buildBloc,
      act: (b) => b.add(const LocalAuthLockExpired()),
      verify: (_) {
        verify(() => mockStorage.write(
              key: 'pin_attempts_left',
              value: '3',
            )).called(1);
        verify(() => mockStorage.delete(key: 'pin_lockout_until')).called(1);
      },
    );
  });
}
