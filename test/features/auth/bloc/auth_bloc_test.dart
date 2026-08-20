import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLocalAuthService extends Mock implements LocalAuthService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

// ─── Fake pour AuthCredential (Google/Apple) ─────────────────────────────────

class FakeAuthCredential extends Fake implements AuthCredential {}

class FakeUserCredential extends Fake implements UserCredential {}

class MockFirebaseUser extends Mock implements User {
  String emailValue = '';
  @override
  String? get email => emailValue;
}

// Google mocks
class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

// Apple fake
class FakeAppleCredential extends Fake
    implements AuthorizationCredentialAppleID {
  @override
  String? get identityToken => 'fake-id-token';
  @override
  String get authorizationCode => 'fake-auth-code';
  @override
  String? get givenName => null;
  @override
  String? get familyName => null;
  @override
  String? get email => null;
  @override
  String get userIdentifier => 'fake-user-id';
  @override
  String? get state => null;
}

void main() {
  late MockAuthRepository mockRepo;
  late MockLocalAuthService mockLocalAuth;
  late MockFirebaseAuth mockFirebaseAuth;
  late Directory tempDir;

  const testUser = UserModel(
    id: 'user-123',
    phoneNumber: '+33612345678',
    roles: ['SENDER'],
    kycStatus: 'PENDING',
    status: 'ACTIVE',
  );

  setUpAll(() async {
    registerFallbackValue(FakeAuthCredential());
    registerFallbackValue(const Duration(seconds: 30));
    // Hive setup needed for OnboardingCompleted tests
    tempDir = await Directory.systemTemp.createTemp('hive_auth_bloc_test');
    Hive.init(p.join(tempDir.path));
    await Hive.openBox('user_prefs');
    await Hive.openBox<Map>(HiveService.offlineQueueBox);
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    mockRepo = MockAuthRepository();
    mockLocalAuth = MockLocalAuthService();
    mockFirebaseAuth = MockFirebaseAuth();
    await Hive.box('user_prefs').clear();
    await Hive.box<Map>(HiveService.offlineQueueBox).clear();
  });

  AuthBloc buildBloc() =>
      AuthBloc(mockRepo, mockLocalAuth, firebaseAuth: mockFirebaseAuth);

  Future<void> seedHiveUserData() async {
    await Hive.box('user_prefs').putAll({
      HiveService.kAnalyticsConsent: true,
      HiveService.kCountryOnboardingSeen: true,
      HiveService.kCountryCode: 'FR',
      HiveService.kCurrencyCode: 'EUR',
      HiveService.kThemeMode: 'dark',
      HiveService.kBiometricEnabled: true,
    });
    await Hive.box<Map>(
      HiveService.offlineQueueBox,
    ).add({'scanId': 'offline-scan-1', 'bidId': 'bid-123'});
  }

  void expectHiveUserDataCleared() {
    expect(Hive.box('user_prefs').isEmpty, isTrue);
    expect(Hive.box<Map>(HiveService.offlineQueueBox).isEmpty, isTrue);
  }

  // ─── AuthCheckRequested ──────────────────────────────────────────────────────

  group('AuthCheckRequested', () {
    blocTest<AuthBloc, AuthState>(
      'utilisateur Firebase null → émet AuthInitial',
      build: () {
        when(() => mockFirebaseAuth.currentUser).thenReturn(null);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [isA<AuthInitial>()],
    );

    blocTest<AuthBloc, AuthState>(
      'utilisateur Firebase connecté + profil backend OK → émet AuthAuthenticated',
      build: () {
        final mockUser = MockUser();
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.phoneNumber).thenReturn('+33612345678');
        when(() => mockRepo.getProfile()).thenAnswer((_) async => testUser);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
      verify: (bloc) {
        verify(() => mockRepo.getProfile()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'utilisateur Firebase connecté + backend 404 → émet AuthInitial',
      build: () {
        final mockUser = MockUser();
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.phoneNumber).thenReturn('+33612345678');
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/auth/me'),
            response: Response(
              requestOptions: RequestOptions(path: '/auth/me'),
              statusCode: 404,
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthInitial>()],
    );

    blocTest<AuthBloc, AuthState>(
      'utilisateur Firebase connecté + erreur réseau → émet AuthError',
      build: () {
        final mockUser = MockUser();
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.phoneNumber).thenReturn('+33612345678');
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/auth/me'),
            response: Response(
              requestOptions: RequestOptions(path: '/auth/me'),
              statusCode: 500,
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );

    blocTest<AuthBloc, AuthState>(
      '401 sur le check initial → AuthError SANS signOut (peut être transitoire, cold start backend)',
      build: () {
        final mockUser = MockUser();
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.phoneNumber).thenReturn('+33612345678');
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/auth/me'),
            response: Response(
              requestOptions: RequestOptions(path: '/auth/me'),
              statusCode: 401,
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
      verify: (_) {
        verifyNever(() => mockFirebaseAuth.signOut());
      },
    );

    blocTest<AuthBloc, AuthState>(
      '403 sur le check initial → AuthError SANS signOut (peut être transitoire, cold start backend)',
      build: () {
        final mockUser = MockUser();
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.phoneNumber).thenReturn('+33612345678');
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/auth/me'),
            response: Response(
              requestOptions: RequestOptions(path: '/auth/me'),
              statusCode: 403,
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
      verify: (_) {
        verifyNever(() => mockFirebaseAuth.signOut());
      },
    );
  });

  // ─── AuthRegisterRequested ───────────────────────────────────────────────────

  group('AuthRegisterRequested', () {
    blocTest<AuthBloc, AuthState>(
      'inscription réussie → émet AuthAuthenticated avec user',
      build: () {
        when(
          () => mockRepo.register(phoneNumber: any(named: 'phoneNumber')),
        ).thenAnswer((_) async => testUser);
        when(() => mockLocalAuth.clearPin()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthRegisterRequested()),
      wait: const Duration(milliseconds: 50),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
      verify: (bloc) {
        verify(
          () => mockRepo.register(phoneNumber: any(named: 'phoneNumber')),
        ).called(1);
        verify(() => mockLocalAuth.clearPin()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'nouvelle inscription nettoie les flags onboarding hérités du compte précédent',
      setUp: () async {
        final prefs = Hive.box('user_prefs');
        await prefs.put(HiveService.kAnalyticsConsent, true);
        await prefs.put(HiveService.kCountryOnboardingSeen, true);
        await prefs.put(HiveService.kTravelerCountryUnsupported, true);
        await prefs.put(HiveService.kCountryCode, 'FR');
        await prefs.put(HiveService.kCurrencyCode, 'EUR');
      },
      build: () {
        when(
          () => mockRepo.register(phoneNumber: any(named: 'phoneNumber')),
        ).thenAnswer((_) async => testUser);
        when(() => mockLocalAuth.clearPin()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthRegisterRequested()),
      wait: const Duration(milliseconds: 50),
      expect: () => [isA<AuthLoading>(), isA<AuthNewAccountAuthenticated>()],
      verify: (_) {
        final prefs = Hive.box('user_prefs');
        expect(prefs.get(HiveService.kAnalyticsConsent), isNull);
        expect(prefs.get(HiveService.kCountryOnboardingSeen), isNull);
        expect(prefs.get(HiveService.kTravelerCountryUnsupported), isNull);
        expect(prefs.get(HiveService.kCountryCode), isNull);
        expect(prefs.get(HiveService.kCurrencyCode), isNull);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'numéro déjà utilisé → émet AuthError avec message localisé',
      build: () {
        when(
          () => mockRepo.register(phoneNumber: any(named: 'phoneNumber')),
        ).thenThrow(Exception('Ce numéro est déjà associé à un compte'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthRegisterRequested()),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>(
          (s) =>
              s is AuthError &&
              s.error.message == 'Ce numéro est déjà associé à un compte',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'erreur générique → émet AuthError',
      build: () {
        when(
          () => mockRepo.register(phoneNumber: any(named: 'phoneNumber')),
        ).thenThrow(Exception('Server error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthRegisterRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );
  });

  // ─── AuthLogoutRequested ─────────────────────────────────────────────────────

  group('AuthLogoutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'déconnexion → émet AuthInitial (PIN conservé)',
      build: () {
        when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      wait: const Duration(milliseconds: 50),
      expect: () => [isA<AuthInitial>()],
      verify: (bloc) {
        verify(() => mockFirebaseAuth.signOut()).called(1);
        // clearPin() ne doit PAS être appelé lors d'un logout simple
        verifyNever(() => mockLocalAuth.clearPin());
      },
    );

    blocTest<AuthBloc, AuthState>(
      'déconnexion → vide les données Hive du compte',
      setUp: seedHiveUserData,
      build: () {
        when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      wait: const Duration(milliseconds: 50),
      expect: () => [isA<AuthInitial>()],
      verify: (_) => expectHiveUserDataCleared(),
    );
  });

  // ─── AuthSwitchAccountRequested ──────────────────────────────────────────────

  group('AuthSwitchAccountRequested', () {
    blocTest<AuthBloc, AuthState>(
      'changement de compte → efface le PIN, déconnecte, émet AuthInitial',
      build: () {
        when(() => mockLocalAuth.clearPin()).thenAnswer((_) async {});
        when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthSwitchAccountRequested()),
      wait: const Duration(milliseconds: 50),
      expect: () => [isA<AuthInitial>()],
      verify: (bloc) {
        // Contrairement au logout simple, le PIN DOIT être effacé : le nouveau
        // compte ne doit pas hériter du PIN du compte précédent.
        verify(() => mockLocalAuth.clearPin()).called(1);
        verify(() => mockFirebaseAuth.signOut()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'changement de compte → vide les données Hive du compte précédent',
      setUp: seedHiveUserData,
      build: () {
        when(() => mockLocalAuth.clearPin()).thenAnswer((_) async {});
        when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthSwitchAccountRequested()),
      wait: const Duration(milliseconds: 50),
      expect: () => [isA<AuthInitial>()],
      verify: (_) => expectHiveUserDataCleared(),
    );
  });

  // ─── AuthDeleteAccountRequested ──────────────────────────────────────────────

  group('AuthDeleteAccountRequested', () {
    blocTest<AuthBloc, AuthState>(
      'suppression réussie → émet AuthAccountDeleted',
      build: () {
        when(() => mockRepo.deleteAccount()).thenAnswer((_) async {});
        when(() => mockLocalAuth.clearPin()).thenAnswer((_) async {});
        when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthDeleteAccountRequested()),
      wait: const Duration(milliseconds: 50),
      expect: () => [isA<AuthLoading>(), isA<AuthAccountDeleted>()],
      verify: (bloc) {
        verify(() => mockRepo.deleteAccount()).called(1);
        verify(() => mockLocalAuth.clearPin()).called(1);
        verify(() => mockFirebaseAuth.signOut()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'suppression réussie → vide les données Hive du compte',
      setUp: seedHiveUserData,
      build: () {
        when(() => mockRepo.deleteAccount()).thenAnswer((_) async {});
        when(() => mockLocalAuth.clearPin()).thenAnswer((_) async {});
        when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthDeleteAccountRequested()),
      wait: const Duration(milliseconds: 50),
      expect: () => [isA<AuthLoading>(), isA<AuthAccountDeleted>()],
      verify: (_) => expectHiveUserDataCleared(),
    );

    blocTest<AuthBloc, AuthState>(
      'erreur suppression → émet AuthError',
      build: () {
        when(
          () => mockRepo.deleteAccount(),
        ).thenThrow(Exception('Erreur suppression'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthDeleteAccountRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );
  });

  // ─── AuthUpdateProfileRequested ──────────────────────────────────────────────

  group('AuthUpdateProfileRequested', () {
    blocTest<AuthBloc, AuthState>(
      'mise à jour réussie → émet AuthProfileUpdated avec user mis à jour',
      build: () {
        const updatedUser = UserModel(
          id: 'user-123',
          firstName: 'Amadou',
          lastName: 'Diallo',
          roles: ['SENDER'],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        when(
          () => mockRepo.updateProfile(
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            birthDate: any(named: 'birthDate'),
            city: any(named: 'city'),
          ),
        ).thenAnswer((_) async => updatedUser);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthUpdateProfileRequested(
          firstName: 'Amadou',
          lastName: 'Diallo',
        ),
      ),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>(
          (s) => s is AuthProfileUpdated && s.user.firstName == 'Amadou',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'erreur mise à jour → émet AuthError',
      build: () {
        when(
          () => mockRepo.updateProfile(
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            birthDate: any(named: 'birthDate'),
            city: any(named: 'city'),
          ),
        ).thenThrow(Exception('Erreur serveur'));
        return buildBloc();
      },
      act: (bloc) =>
          bloc.add(const AuthUpdateProfileRequested(firstName: 'Amadou')),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );
  });

  // ─── AuthPhoneVerified ───────────────────────────────────────────────────────

  group('AuthPhoneVerified', () {
    blocTest<AuthBloc, AuthState>(
      'compte existant → vérifie le code côté backend puis émet [Loading, AuthAuthenticated]',
      build: () {
        when(
          () => mockRepo.verifyPhoneOtp(any(), any()),
        ).thenAnswer((_) async => 'custom_token_fake');
        when(
          () => mockFirebaseAuth.signInWithCustomToken('custom_token_fake'),
        ).thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenAnswer((_) async => testUser);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthPhoneVerified(verificationId: 'ver-abc', smsCode: '123456'),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
      verify: (_) {
        verify(() => mockRepo.verifyPhoneOtp('', '123456')).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'nouveau numéro (404) → émet [Loading, AuthOtpVerified]',
      build: () {
        when(
          () => mockRepo.verifyPhoneOtp(any(), any()),
        ).thenAnswer((_) async => 'custom_token_fake');
        when(
          () => mockFirebaseAuth.signInWithCustomToken('custom_token_fake'),
        ).thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/auth/me'),
            response: Response(
              requestOptions: RequestOptions(path: '/auth/me'),
              statusCode: 404,
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthPhoneVerified(verificationId: 'ver-abc', smsCode: '123456'),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthOtpVerified>()],
    );

    blocTest<AuthBloc, AuthState>(
      'erreur backend non-404 → émet [Loading, AuthError]',
      build: () {
        when(
          () => mockRepo.verifyPhoneOtp(any(), any()),
        ).thenAnswer((_) async => 'custom_token_fake');
        when(
          () => mockFirebaseAuth.signInWithCustomToken('custom_token_fake'),
        ).thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/auth/me'),
            response: Response(
              requestOptions: RequestOptions(path: '/auth/me'),
              statusCode: 500,
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthPhoneVerified(verificationId: 'ver-abc', smsCode: '123456'),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );

    blocTest<AuthBloc, AuthState>(
      'verifyPhoneOtp rejeté (code invalide côté backend) → émet [Loading, AuthError]',
      build: () {
        when(() => mockRepo.verifyPhoneOtp(any(), any())).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/auth/sms-otp/verify'),
            response: Response(
              requestOptions: RequestOptions(path: '/auth/sms-otp/verify'),
              statusCode: 400,
              data: {'code': 'phone-otp-invalid', 'detail': 'Code invalide'},
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthPhoneVerified(verificationId: 'ver-abc', smsCode: '000000'),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
      verify: (_) {
        verifyNever(() => mockFirebaseAuth.signInWithCustomToken(any()));
      },
    );
  });

  // ─── AuthPhoneVerified — cas non couverts ────────────────────────────────────

  group('AuthPhoneVerified — erreurs supplémentaires', () {
    blocTest<AuthBloc, AuthState>(
      'getProfile lance exception générique → émet AuthOtpVerified',
      build: () {
        when(
          () => mockRepo.verifyPhoneOtp(any(), any()),
        ).thenAnswer((_) async => 'custom_token_fake');
        when(
          () => mockFirebaseAuth.signInWithCustomToken('custom_token_fake'),
        ).thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenThrow(Exception('parse error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthPhoneVerified(verificationId: 'ver-abc', smsCode: '123456'),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthOtpVerified>()],
    );

    blocTest<AuthBloc, AuthState>(
      'signInWithCustomToken lance Exception générique → émet AuthError',
      build: () {
        when(
          () => mockRepo.verifyPhoneOtp(any(), any()),
        ).thenAnswer((_) async => 'custom_token_fake');
        when(
          () => mockFirebaseAuth.signInWithCustomToken('custom_token_fake'),
        ).thenThrow(Exception('unexpected sign-in error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthPhoneVerified(verificationId: 'ver-abc', smsCode: '123456'),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );
  });

  // ─── AuthCheckRequested generic exception ────────────────────────────────────

  group('AuthCheckRequested generic exception', () {
    blocTest<AuthBloc, AuthState>(
      'exception non-Dio → émet [Loading, AuthInitial]',
      build: () {
        final mockUser = MockUser();
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.phoneNumber).thenReturn('+33699999999');
        when(() => mockRepo.getProfile()).thenThrow(Exception('timeout'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthInitial>()],
    );
  });

  // ─── État initial ────────────────────────────────────────────────────────────

  group('État initial', () {
    test('état initial est AuthInitial', () {
      expect(buildBloc().state, isA<AuthInitial>());
    });
  });

  // ─── AuthAuthenticated ───────────────────────────────────────────────────────

  group('AuthAuthenticated props', () {
    test('deux états avec le même user sont égaux', () {
      const s1 = AuthAuthenticated(testUser);
      const s2 = AuthAuthenticated(testUser);
      expect(s1, equals(s2));
    });
  });

  // ─── AuthOtpSent props ───────────────────────────────────────────────────────

  group('AuthOtpSent props', () {
    test('props contient verificationId et phoneNumber', () {
      // ignore: prefer_const_constructors
      final state = AuthOtpSent(
        verificationId: 'ver-123',
        phoneNumber: '+33612345678',
      );
      expect(state.props, containsAllInOrder(['ver-123', '+33612345678']));
    });
  });

  group('AuthLocked', () {
    test('AuthLocked constructs', () {
      // ignore: prefer_const_constructors
      final s = AuthLocked();
      expect(s, isA<AuthLocked>());
    });
  });

  // ─── AuthDialCodeChanged ─────────────────────────────────────────────────────

  group('AuthDialCodeChanged', () {
    blocTest<AuthBloc, AuthState>(
      'emits AuthInitial with new dial code',
      build: buildBloc,
      act: (bloc) =>
          bloc.add(const AuthDialCodeChanged(code: '+221', flag: '🇸🇳')),
      expect: () => [const AuthInitial(dialCode: '+221', dialFlag: '🇸🇳')],
    );

    blocTest<AuthBloc, AuthState>(
      'preserves dial code when emitted from error state',
      build: buildBloc,
      seed: () => const AuthError(NetworkException('Erreur réseau')),
      act: (bloc) =>
          bloc.add(const AuthDialCodeChanged(code: '+237', flag: '🇨🇲')),
      expect: () => [const AuthInitial(dialCode: '+237', dialFlag: '🇨🇲')],
    );
  });

  // ─── AuthOtpTimerTicked ──────────────────────────────────────────────────────

  group('AuthOtpTimerTicked', () {
    blocTest<AuthBloc, AuthState>(
      'decrements secondsLeft in AuthOtpSent',
      build: buildBloc,
      seed: () => const AuthOtpSent(
        verificationId: 'ver-123',
        phoneNumber: '+33612345678',
      ),
      act: (bloc) => bloc.add(const AuthOtpTimerTicked()),
      expect: () => [
        const AuthOtpSent(
          verificationId: 'ver-123',
          phoneNumber: '+33612345678',
          secondsLeft: 59,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'does not emit when secondsLeft is already 0',
      build: buildBloc,
      seed: () => const AuthOtpSent(
        verificationId: 'ver-123',
        phoneNumber: '+33612345678',
        secondsLeft: 0,
      ),
      act: (bloc) => bloc.add(const AuthOtpTimerTicked()),
      expect: () => [],
    );
  });

  // ─── AuthGoogleSignInRequested ───────────────────────────────────────────────

  group('AuthGoogleSignInRequested', () {
    late MockGoogleSignIn mockGoogleSignIn;
    late MockGoogleSignInAccount mockGoogleAccount;
    late MockGoogleSignInAuthentication mockGoogleAuth;

    setUp(() {
      mockGoogleSignIn = MockGoogleSignIn();
      mockGoogleAccount = MockGoogleSignInAccount();
      mockGoogleAuth = MockGoogleSignInAuthentication();

      when(
        () => mockGoogleSignIn.signIn(),
      ).thenAnswer((_) async => mockGoogleAccount);
      when(
        () => mockGoogleAccount.authentication,
      ).thenAnswer((_) async => mockGoogleAuth);
      when(() => mockGoogleAuth.accessToken).thenReturn('access-token');
      when(() => mockGoogleAuth.idToken).thenReturn('id-token');
    });

    AuthBloc buildGoogleBloc() => AuthBloc(
      mockRepo,
      mockLocalAuth,
      firebaseAuth: mockFirebaseAuth,
      googleSignIn: mockGoogleSignIn,
    );

    blocTest<AuthBloc, AuthState>(
      'émet [Loading, Authenticated] quand compte existant',
      build: buildGoogleBloc,
      setUp: () {
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenAnswer((_) async => testUser);
      },
      act: (b) => b.add(const AuthGoogleSignInRequested()),
      expect: () => [const AuthLoading(), const AuthAuthenticated(testUser)],
    );

    blocTest<AuthBloc, AuthState>(
      'émet [Loading, AuthOAuthNewUser] quand nouveau compte (404)',
      build: () {
        final mockGoogleUser = MockGoogleSignInAccount();
        final mockGoogleAuth = MockGoogleSignInAuthentication();
        final mockGoogleSignIn = MockGoogleSignIn();
        final mockFirebaseUser = MockFirebaseUser()
          ..emailValue = 'newuser@gmail.com';
        when(
          () => mockGoogleSignIn.signIn(),
        ).thenAnswer((_) async => mockGoogleUser);
        when(
          () => mockGoogleUser.authentication,
        ).thenAnswer((_) async => mockGoogleAuth);
        when(() => mockGoogleAuth.accessToken).thenReturn('access');
        when(() => mockGoogleAuth.idToken).thenReturn('id');
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => FakeUserCredential());
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockFirebaseUser);
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              statusCode: 404,
              requestOptions: RequestOptions(),
            ),
          ),
        );
        return AuthBloc(
          mockRepo,
          mockLocalAuth,
          firebaseAuth: mockFirebaseAuth,
          googleSignIn: mockGoogleSignIn,
        );
      },
      act: (b) => b.add(const AuthGoogleSignInRequested()),
      expect: () => [
        const AuthLoading(),
        isA<AuthOAuthNewUser>().having(
          (s) => s.email,
          'email',
          'newuser@gmail.com',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'émet [Loading, Initial] quand utilisateur annule Google sign-in',
      build: () => AuthBloc(
        mockRepo,
        mockLocalAuth,
        firebaseAuth: mockFirebaseAuth,
        googleSignIn: mockGoogleSignIn,
      ),
      setUp: () {
        when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => null);
      },
      act: (b) => b.add(const AuthGoogleSignInRequested()),
      expect: () => [const AuthLoading(), const AuthInitial()],
    );

    blocTest<AuthBloc, AuthState>(
      'émet [Loading, AuthError] quand backend répond 500',
      build: buildGoogleBloc,
      setUp: () {
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              statusCode: 500,
              requestOptions: RequestOptions(),
            ),
          ),
        );
      },
      act: (b) => b.add(const AuthGoogleSignInRequested()),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── AuthAppleSignInRequested ────────────────────────────────────────────────

  group('AuthAppleSignInRequested', () {
    blocTest<AuthBloc, AuthState>(
      'émet [Loading, Authenticated] quand compte existant',
      build: () => AuthBloc(
        mockRepo,
        mockLocalAuth,
        firebaseAuth: mockFirebaseAuth,
        appleSignIn: (_) async => FakeAppleCredential(),
      ),
      setUp: () {
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenAnswer((_) async => testUser);
      },
      act: (b) => b.add(const AuthAppleSignInRequested()),
      expect: () => [const AuthLoading(), const AuthAuthenticated(testUser)],
    );

    blocTest<AuthBloc, AuthState>(
      'émet [Loading, AuthOAuthNewUser] quand nouveau compte (404)',
      build: () {
        final mockFirebaseUser = MockFirebaseUser()
          ..emailValue = 'newaple@icloud.com';
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => FakeUserCredential());
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockFirebaseUser);
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              statusCode: 404,
              requestOptions: RequestOptions(),
            ),
          ),
        );
        return AuthBloc(
          mockRepo,
          mockLocalAuth,
          firebaseAuth: mockFirebaseAuth,
          appleSignIn: (_) async => FakeAppleCredential(),
        );
      },
      act: (b) => b.add(const AuthAppleSignInRequested()),
      expect: () => [
        const AuthLoading(),
        isA<AuthOAuthNewUser>().having(
          (s) => s.email,
          'email',
          'newaple@icloud.com',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'émet [Loading, AuthError] quand backend répond 500',
      build: () => AuthBloc(
        mockRepo,
        mockLocalAuth,
        firebaseAuth: mockFirebaseAuth,
        appleSignIn: (_) async => FakeAppleCredential(),
      ),
      setUp: () {
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              statusCode: 500,
              requestOptions: RequestOptions(),
            ),
          ),
        );
      },
      act: (b) => b.add(const AuthAppleSignInRequested()),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── AuthEmailOtpSendRequested ────────────────────────────────────────────────

  group('AuthEmailOtpSendRequested', () {
    blocTest<AuthBloc, AuthState>(
      'émet [AuthLoading, AuthEmailOtpSent] en cas de succès',
      build: () {
        when(() => mockRepo.sendEmailOtp('a@b.com')).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthEmailOtpSendRequested('a@b.com')),
      expect: () => [
        const AuthLoading(),
        isA<AuthEmailOtpSent>().having((s) => s.email, 'email', 'a@b.com'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'émet [AuthLoading, AuthError] si le repository lance une exception',
      build: () {
        when(
          () => mockRepo.sendEmailOtp(any()),
        ).thenThrow(Exception('network error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthEmailOtpSendRequested('a@b.com')),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── AuthEmailOtpVerifyRequested ─────────────────────────────────────────────

  group('AuthEmailOtpVerifyRequested', () {
    blocTest<AuthBloc, AuthState>(
      'émet [AuthLoading, AuthEmailOtpVerified] en cas de succès (nouveau compte)',
      build: () {
        when(
          () => mockRepo.verifyEmailOtp('a@b.com', '123456'),
        ).thenAnswer((_) async => 'custom_token_fake');
        when(
          () => mockFirebaseAuth.signInWithCustomToken('custom_token_fake'),
        ).thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/users/me'),
            response: Response(
              requestOptions: RequestOptions(path: '/users/me'),
              statusCode: 404,
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthEmailOtpVerifyRequested(email: 'a@b.com', code: '123456'),
      ),
      expect: () => [
        const AuthLoading(),
        isA<AuthEmailOtpVerified>().having((s) => s.email, 'email', 'a@b.com'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'émet [AuthLoading, AuthError] si code invalide',
      build: () {
        when(
          () => mockRepo.verifyEmailOtp(any(), any()),
        ).thenThrow(Exception('invalid code'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthEmailOtpVerifyRequested(email: 'a@b.com', code: '000000'),
      ),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── AuthAddEmailFromProfileRequested ────────────────────────────────────────

  group('AuthAddEmailFromProfileRequested', () {
    blocTest<AuthBloc, AuthState>(
      'succès → un seul appel attachEmail (email+code), émet AuthProfileUpdated',
      build: () {
        when(
          () => mockRepo.attachEmail(email: 'a@b.com', code: '123456'),
        ).thenAnswer((_) async => testUser);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthAddEmailFromProfileRequested(
          email: 'a@b.com',
          code: '123456',
        ),
      ),
      expect: () => [const AuthLoading(), isA<AuthProfileUpdated>()],
      verify: (_) {
        // La vérification et l'écriture ne sont plus deux appels séparés
        verify(
          () => mockRepo.attachEmail(email: 'a@b.com', code: '123456'),
        ).called(1);
        verifyNever(() => mockRepo.verifyEmailOtp(any(), any()));
      },
    );

    blocTest<AuthBloc, AuthState>(
      'échec backend (409 email déjà défini) → AuthError',
      build: () {
        when(
          () => mockRepo.attachEmail(email: 'a@b.com', code: '123456'),
        ).thenThrow(Exception('email-already-set'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthAddEmailFromProfileRequested(
          email: 'a@b.com',
          code: '123456',
        ),
      ),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── AuthAddPhoneFromProfileRequested ────────────────────────────────────────

  group('AuthAddPhoneFromProfileRequested', () {
    blocTest<AuthBloc, AuthState>(
      'succès → un seul appel attachPhone (phoneNumber+code), émet AuthProfileUpdated',
      build: () {
        when(
          () => mockRepo.attachPhone(
            phoneNumber: '+221701234567',
            code: '123456',
          ),
        ).thenAnswer((_) async => testUser);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthAddPhoneFromProfileRequested(
          phoneNumber: '+221701234567',
          code: '123456',
        ),
      ),
      expect: () => [const AuthLoading(), isA<AuthProfileUpdated>()],
      verify: (_) {
        // La vérification et l'écriture ne sont plus deux appels séparés
        verify(
          () => mockRepo.attachPhone(
            phoneNumber: '+221701234567',
            code: '123456',
          ),
        ).called(1);
        verifyNever(() => mockRepo.verifyPhoneOtp(any(), any()));
        verifyNever(() => mockFirebaseAuth.currentUser);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'échec backend (409 numéro déjà défini) → AuthError',
      build: () {
        when(
          () => mockRepo.attachPhone(
            phoneNumber: '+221701234567',
            code: '123456',
          ),
        ).thenThrow(Exception('phone-already-set'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthAddPhoneFromProfileRequested(
          phoneNumber: '+221701234567',
          code: '123456',
        ),
      ),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── AuthRegisterWithEmailRequested ──────────────────────────────────────────

  group('AuthRegisterWithEmailRequested', () {
    blocTest<AuthBloc, AuthState>(
      'émet [AuthLoading, AuthAuthenticated] en cas de succès',
      build: () {
        when(
          () => mockRepo.registerWithEmail(email: 'a@b.com'),
        ).thenAnswer((_) async => testUser);
        when(() => mockLocalAuth.clearPin()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) =>
          bloc.add(const AuthRegisterWithEmailRequested(email: 'a@b.com')),
      wait: const Duration(milliseconds: 50),
      expect: () => [const AuthLoading(), isA<AuthAuthenticated>()],
      verify: (_) {
        verify(() => mockLocalAuth.clearPin()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'inscription email nettoie les flags onboarding hérités du compte précédent',
      setUp: () async {
        final prefs = Hive.box('user_prefs');
        await prefs.put(HiveService.kAnalyticsConsent, false);
        await prefs.put(HiveService.kCountryOnboardingSeen, true);
        await prefs.put(HiveService.kTravelerCountryUnsupported, true);
        await prefs.put(HiveService.kCountryCode, 'FR');
        await prefs.put(HiveService.kCurrencyCode, 'EUR');
      },
      build: () {
        when(
          () => mockRepo.registerWithEmail(email: 'a@b.com'),
        ).thenAnswer((_) async => testUser);
        when(() => mockLocalAuth.clearPin()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) =>
          bloc.add(const AuthRegisterWithEmailRequested(email: 'a@b.com')),
      wait: const Duration(milliseconds: 50),
      expect: () => [const AuthLoading(), isA<AuthNewAccountAuthenticated>()],
      verify: (_) {
        final prefs = Hive.box('user_prefs');
        expect(prefs.get(HiveService.kAnalyticsConsent), isNull);
        expect(prefs.get(HiveService.kCountryOnboardingSeen), isNull);
        expect(prefs.get(HiveService.kTravelerCountryUnsupported), isNull);
        expect(prefs.get(HiveService.kCountryCode), isNull);
        expect(prefs.get(HiveService.kCurrencyCode), isNull);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'émet [AuthLoading, AuthError] si register échoue',
      build: () {
        when(
          () => mockRepo.registerWithEmail(email: any(named: 'email')),
        ).thenThrow(Exception('email already exists'));
        when(() => mockLocalAuth.clearPin()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) =>
          bloc.add(const AuthRegisterWithEmailRequested(email: 'a@b.com')),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── Fix AuthGoogleSignInRequested → AuthOAuthNewUser (nouveau user) ──────────

  group('AuthGoogleSignInRequested 404 → AuthOAuthNewUser', () {
    blocTest<AuthBloc, AuthState>(
      'émet AuthOAuthNewUser (pas AuthOtpVerified) quand GET /me retourne 404',
      build: () {
        final mockGoogleUser = MockGoogleSignInAccount();
        final mockGoogleAuth = MockGoogleSignInAuthentication();
        final mockGoogleSignIn = MockGoogleSignIn();
        final mockFirebaseUser = MockFirebaseUser()
          ..emailValue = 'test@gmail.com';
        when(
          () => mockGoogleSignIn.signIn(),
        ).thenAnswer((_) async => mockGoogleUser);
        when(
          () => mockGoogleUser.authentication,
        ).thenAnswer((_) async => mockGoogleAuth);
        when(() => mockGoogleAuth.accessToken).thenReturn('access');
        when(() => mockGoogleAuth.idToken).thenReturn('id');
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => FakeUserCredential());
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockFirebaseUser);
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/auth/me'),
            response: Response(
              requestOptions: RequestOptions(path: '/auth/me'),
              statusCode: 404,
            ),
          ),
        );
        return AuthBloc(
          mockRepo,
          mockLocalAuth,
          firebaseAuth: mockFirebaseAuth,
          googleSignIn: mockGoogleSignIn,
        );
      },
      act: (bloc) => bloc.add(const AuthGoogleSignInRequested()),
      expect: () => [
        const AuthLoading(),
        isA<AuthOAuthNewUser>().having(
          (s) => s.email,
          'email',
          'test@gmail.com',
        ),
      ],
    );
  });

  // ─── AuthOtpTimerTicked — AuthEmailOtpSent branch ───────────────────────────

  group('AuthOtpTimerTicked — AuthEmailOtpSent', () {
    blocTest<AuthBloc, AuthState>(
      'decrements secondsLeft in AuthEmailOtpSent',
      build: buildBloc,
      seed: () => const AuthEmailOtpSent('user@example.com', secondsLeft: 30),
      act: (bloc) => bloc.add(const AuthOtpTimerTicked()),
      expect: () => [
        const AuthEmailOtpSent('user@example.com', secondsLeft: 29),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'does not emit when AuthEmailOtpSent secondsLeft is already 0',
      build: buildBloc,
      seed: () => const AuthEmailOtpSent('user@example.com', secondsLeft: 0),
      act: (bloc) => bloc.add(const AuthOtpTimerTicked()),
      expect: () => [],
    );
  });

  // ─── OnboardingCompleted ─────────────────────────────────────────────────────

  group('OnboardingCompleted', () {
    blocTest<AuthBloc, AuthState>(
      'writes onboarding_done=true to Hive and emits nothing',
      build: buildBloc,
      act: (bloc) => bloc.add(const OnboardingCompleted()),
      expect: () => [],
      verify: (_) {
        expect(Hive.box('user_prefs').get('onboarding_done'), isTrue);
      },
    );
  });

  // ─── _checkProfileAfterOAuth — generic exception ─────────────────────────────

  group('_checkProfileAfterOAuth — generic exception', () {
    blocTest<AuthBloc, AuthState>(
      'Google: getProfile throws generic exception → émet AuthError',
      build: () {
        final mockGoogleSignIn = MockGoogleSignIn();
        final mockGoogleUser = MockGoogleSignInAccount();
        final mockGoogleAuth = MockGoogleSignInAuthentication();
        final mockFirebaseUser = MockFirebaseUser()
          ..emailValue = 'user@gmail.com';
        when(
          () => mockGoogleSignIn.signIn(),
        ).thenAnswer((_) async => mockGoogleUser);
        when(
          () => mockGoogleUser.authentication,
        ).thenAnswer((_) async => mockGoogleAuth);
        when(() => mockGoogleAuth.accessToken).thenReturn('access');
        when(() => mockGoogleAuth.idToken).thenReturn('id');
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => FakeUserCredential());
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockFirebaseUser);
        when(
          () => mockRepo.getProfile(),
        ).thenThrow(Exception('unexpected parse error'));
        return AuthBloc(
          mockRepo,
          mockLocalAuth,
          firebaseAuth: mockFirebaseAuth,
          googleSignIn: mockGoogleSignIn,
        );
      },
      act: (b) => b.add(const AuthGoogleSignInRequested()),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );

    blocTest<AuthBloc, AuthState>(
      'Apple: getProfile throws generic exception → émet AuthError',
      build: () {
        final mockFirebaseUser = MockFirebaseUser()
          ..emailValue = 'user@icloud.com';
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => FakeUserCredential());
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockFirebaseUser);
        when(
          () => mockRepo.getProfile(),
        ).thenThrow(Exception('unexpected parse error'));
        return AuthBloc(
          mockRepo,
          mockLocalAuth,
          firebaseAuth: mockFirebaseAuth,
          appleSignIn: (_) async => FakeAppleCredential(),
        );
      },
      act: (b) => b.add(const AuthAppleSignInRequested()),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── Google/Apple — currentUser?.email path ──────────────────────────────────

  group('AuthGoogleSignInRequested — currentUser.email assigned', () {
    blocTest<AuthBloc, AuthState>(
      'émet [Loading, Authenticated] et assigne email depuis currentUser',
      build: () {
        final mockGoogleSignIn = MockGoogleSignIn();
        final mockGoogleUser = MockGoogleSignInAccount();
        final mockGoogleAuth = MockGoogleSignInAuthentication();
        final mockFirebaseUser = MockFirebaseUser()
          ..emailValue = 'user@gmail.com';
        when(
          () => mockGoogleSignIn.signIn(),
        ).thenAnswer((_) async => mockGoogleUser);
        when(
          () => mockGoogleUser.authentication,
        ).thenAnswer((_) async => mockGoogleAuth);
        when(() => mockGoogleAuth.accessToken).thenReturn('access');
        when(() => mockGoogleAuth.idToken).thenReturn('id');
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => FakeUserCredential());
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockFirebaseUser);
        when(() => mockRepo.getProfile()).thenAnswer((_) async => testUser);
        return AuthBloc(
          mockRepo,
          mockLocalAuth,
          firebaseAuth: mockFirebaseAuth,
          googleSignIn: mockGoogleSignIn,
        );
      },
      act: (b) => b.add(const AuthGoogleSignInRequested()),
      expect: () => [const AuthLoading(), const AuthAuthenticated(testUser)],
    );
  });

  group('AuthAppleSignInRequested — currentUser.email assigned', () {
    blocTest<AuthBloc, AuthState>(
      'émet [Loading, Authenticated] et assigne email depuis currentUser',
      build: () {
        final mockFirebaseUser = MockFirebaseUser()
          ..emailValue = 'user@icloud.com';
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => FakeUserCredential());
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockFirebaseUser);
        when(() => mockRepo.getProfile()).thenAnswer((_) async => testUser);
        return AuthBloc(
          mockRepo,
          mockLocalAuth,
          firebaseAuth: mockFirebaseAuth,
          appleSignIn: (_) async => FakeAppleCredential(),
        );
      },
      act: (b) => b.add(const AuthAppleSignInRequested()),
      expect: () => [const AuthLoading(), const AuthAuthenticated(testUser)],
    );
  });

  // ─── catch(e) dans _onGoogleSignInRequested et _onAppleSignInRequested ─────

  group('OAuth outer catch(e)', () {
    blocTest<AuthBloc, AuthState>(
      'Google: signIn() throws generic exception → émet [Loading, AuthError]',
      build: () {
        final mockGoogleSignIn = MockGoogleSignIn();
        when(
          () => mockGoogleSignIn.signIn(),
        ).thenThrow(Exception('Google play services unavailable'));
        return AuthBloc(
          mockRepo,
          mockLocalAuth,
          firebaseAuth: mockFirebaseAuth,
          googleSignIn: mockGoogleSignIn,
        );
      },
      act: (b) => b.add(const AuthGoogleSignInRequested()),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );

    blocTest<AuthBloc, AuthState>(
      'Apple: appleSignIn() throws generic exception → émet [Loading, AuthError]',
      build: () => AuthBloc(
        mockRepo,
        mockLocalAuth,
        firebaseAuth: mockFirebaseAuth,
        appleSignIn: (_) async => throw Exception('Apple auth unavailable'),
      ),
      act: (b) => b.add(const AuthAppleSignInRequested()),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── AuthSendOtpRequested — envoi backend (Twilio/Africa's Talking) ──────────

  group('AuthSendOtpRequested', () {
    blocTest<AuthBloc, AuthState>(
      'succès → émet [Loading, AuthOtpSent]',
      build: () {
        when(
          () => mockRepo.sendPhoneOtp('+33612345678'),
        ).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthSendOtpRequested('+33612345678')),
      expect: () => [
        const AuthLoading(),
        isA<AuthOtpSent>()
            .having((s) => s.phoneNumber, 'phoneNumber', '+33612345678')
            .having((s) => s.secondsLeft, 'secondsLeft', 60),
      ],
      verify: (_) {
        verify(() => mockRepo.sendPhoneOtp('+33612345678')).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'rate-limit backend (429) → émet [Loading, AuthError]',
      build: () {
        when(() => mockRepo.sendPhoneOtp(any())).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/auth/sms-otp/send'),
            response: Response(
              requestOptions: RequestOptions(path: '/auth/sms-otp/send'),
              statusCode: 429,
              data: {
                'code': 'phone-otp-rate-limit',
                'detail': 'Trop de tentatives',
              },
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthSendOtpRequested('+33612345678')),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );

    blocTest<AuthBloc, AuthState>(
      'exception générique → émet [Loading, AuthError]',
      build: () {
        when(
          () => mockRepo.sendPhoneOtp(any()),
        ).thenThrow(Exception('network error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthSendOtpRequested('+33612345678')),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );

    blocTest<AuthBloc, AuthState>(
      'émet [Loading, AuthError] quand backend répond 500',
      build: () => AuthBloc(
        mockRepo,
        mockLocalAuth,
        firebaseAuth: mockFirebaseAuth,
        appleSignIn: (_) async => FakeAppleCredential(),
      ),
      setUp: () {
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              statusCode: 500,
              requestOptions: RequestOptions(),
            ),
          ),
        );
      },
      act: (b) => b.add(const AuthAppleSignInRequested()),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── AuthEmailOtpSendRequested ────────────────────────────────────────────────

  group('AuthEmailOtpSendRequested', () {
    blocTest<AuthBloc, AuthState>(
      'émet [AuthLoading, AuthEmailOtpSent] en cas de succès',
      build: () {
        when(() => mockRepo.sendEmailOtp('a@b.com')).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthEmailOtpSendRequested('a@b.com')),
      expect: () => [
        const AuthLoading(),
        isA<AuthEmailOtpSent>().having((s) => s.email, 'email', 'a@b.com'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'émet [AuthLoading, AuthError] si le repository lance une exception',
      build: () {
        when(
          () => mockRepo.sendEmailOtp(any()),
        ).thenThrow(Exception('network error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthEmailOtpSendRequested('a@b.com')),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── AuthEmailOtpVerifyRequested ─────────────────────────────────────────────

  group('AuthEmailOtpVerifyRequested', () {
    blocTest<AuthBloc, AuthState>(
      'nouveau compte (404 sur verifyEmailOtp) → émet [AuthLoading, AuthEmailOtpVerified]',
      build: () {
        when(() => mockRepo.verifyEmailOtp('a@b.com', '123456')).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/auth/email/verify'),
            response: Response(
              requestOptions: RequestOptions(path: '/auth/email/verify'),
              statusCode: 404,
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthEmailOtpVerifyRequested(email: 'a@b.com', code: '123456'),
      ),
      expect: () => [
        const AuthLoading(),
        isA<AuthEmailOtpVerified>().having((s) => s.email, 'email', 'a@b.com'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'émet [AuthLoading, AuthError] si code invalide',
      build: () {
        when(
          () => mockRepo.verifyEmailOtp(any(), any()),
        ).thenThrow(Exception('invalid code'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthEmailOtpVerifyRequested(email: 'a@b.com', code: '000000'),
      ),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── AuthRegisterWithEmailRequested ──────────────────────────────────────────

  group('AuthRegisterWithEmailRequested', () {
    const fakeUser = UserModel(
      id: 'user-email-1',
      email: 'a@b.com',
      roles: ['SENDER'],
      kycStatus: 'PENDING',
      status: 'ACTIVE',
    );

    blocTest<AuthBloc, AuthState>(
      'émet [AuthLoading, AuthAuthenticated] en cas de succès',
      build: () {
        when(
          () => mockRepo.registerWithEmail(email: 'a@b.com'),
        ).thenAnswer((_) async => fakeUser);
        when(() => mockLocalAuth.clearPin()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) =>
          bloc.add(const AuthRegisterWithEmailRequested(email: 'a@b.com')),
      wait: const Duration(milliseconds: 50),
      expect: () => [const AuthLoading(), isA<AuthAuthenticated>()],
      verify: (_) {
        verify(() => mockLocalAuth.clearPin()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'émet [AuthLoading, AuthError] si register échoue',
      build: () {
        when(
          () => mockRepo.registerWithEmail(email: any(named: 'email')),
        ).thenThrow(Exception('email already exists'));
        when(() => mockLocalAuth.clearPin()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) =>
          bloc.add(const AuthRegisterWithEmailRequested(email: 'a@b.com')),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── Fix AuthGoogleSignInRequested → AuthOAuthNewUser (nouveau user) ──────────

  group('AuthGoogleSignInRequested 404 → AuthOAuthNewUser', () {
    blocTest<AuthBloc, AuthState>(
      'émet AuthOAuthNewUser (pas AuthOtpVerified) quand GET /me retourne 404',
      build: () {
        final mockGoogleUser = MockGoogleSignInAccount();
        final mockGoogleAuth = MockGoogleSignInAuthentication();
        final mockGoogleSignIn = MockGoogleSignIn();
        final mockFirebaseUser = MockFirebaseUser()
          ..emailValue = 'test@gmail.com';
        when(
          () => mockGoogleSignIn.signIn(),
        ).thenAnswer((_) async => mockGoogleUser);
        when(
          () => mockGoogleUser.authentication,
        ).thenAnswer((_) async => mockGoogleAuth);
        when(() => mockGoogleAuth.accessToken).thenReturn('access');
        when(() => mockGoogleAuth.idToken).thenReturn('id');
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => FakeUserCredential());
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockFirebaseUser);
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/auth/me'),
            response: Response(
              requestOptions: RequestOptions(path: '/auth/me'),
              statusCode: 404,
            ),
          ),
        );
        return AuthBloc(
          mockRepo,
          mockLocalAuth,
          firebaseAuth: mockFirebaseAuth,
          googleSignIn: mockGoogleSignIn,
        );
      },
      act: (bloc) => bloc.add(const AuthGoogleSignInRequested()),
      expect: () => [
        const AuthLoading(),
        isA<AuthOAuthNewUser>().having(
          (s) => s.email,
          'email',
          'test@gmail.com',
        ),
      ],
    );
  });

  // ─── AuthOtpTimerTicked — AuthEmailOtpSent branch ───────────────────────────

  group('AuthOtpTimerTicked — AuthEmailOtpSent', () {
    blocTest<AuthBloc, AuthState>(
      'decrements secondsLeft in AuthEmailOtpSent',
      build: buildBloc,
      seed: () => const AuthEmailOtpSent('user@example.com', secondsLeft: 30),
      act: (bloc) => bloc.add(const AuthOtpTimerTicked()),
      expect: () => [
        const AuthEmailOtpSent('user@example.com', secondsLeft: 29),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'does not emit when AuthEmailOtpSent secondsLeft is already 0',
      build: buildBloc,
      seed: () => const AuthEmailOtpSent('user@example.com', secondsLeft: 0),
      act: (bloc) => bloc.add(const AuthOtpTimerTicked()),
      expect: () => [],
    );
  });

  // ─── OnboardingCompleted ─────────────────────────────────────────────────────

  group('OnboardingCompleted', () {
    blocTest<AuthBloc, AuthState>(
      'writes onboarding_done=true to Hive and emits nothing',
      build: buildBloc,
      act: (bloc) => bloc.add(const OnboardingCompleted()),
      expect: () => [],
      verify: (_) {
        expect(Hive.box('user_prefs').get('onboarding_done'), isTrue);
      },
    );
  });

  // ─── _checkProfileAfterOAuth — generic exception ─────────────────────────────

  group('_checkProfileAfterOAuth — generic exception', () {
    blocTest<AuthBloc, AuthState>(
      'Google: getProfile throws generic exception → émet AuthError',
      build: () {
        final mockGoogleSignIn = MockGoogleSignIn();
        final mockGoogleUser = MockGoogleSignInAccount();
        final mockGoogleAuth = MockGoogleSignInAuthentication();
        final mockFirebaseUser = MockFirebaseUser()
          ..emailValue = 'user@gmail.com';
        when(
          () => mockGoogleSignIn.signIn(),
        ).thenAnswer((_) async => mockGoogleUser);
        when(
          () => mockGoogleUser.authentication,
        ).thenAnswer((_) async => mockGoogleAuth);
        when(() => mockGoogleAuth.accessToken).thenReturn('access');
        when(() => mockGoogleAuth.idToken).thenReturn('id');
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => FakeUserCredential());
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockFirebaseUser);
        when(
          () => mockRepo.getProfile(),
        ).thenThrow(Exception('unexpected parse error'));
        return AuthBloc(
          mockRepo,
          mockLocalAuth,
          firebaseAuth: mockFirebaseAuth,
          googleSignIn: mockGoogleSignIn,
        );
      },
      act: (b) => b.add(const AuthGoogleSignInRequested()),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );

    blocTest<AuthBloc, AuthState>(
      'Apple: getProfile throws generic exception → émet AuthError',
      build: () {
        final mockFirebaseUser = MockFirebaseUser()
          ..emailValue = 'user@icloud.com';
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => FakeUserCredential());
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockFirebaseUser);
        when(
          () => mockRepo.getProfile(),
        ).thenThrow(Exception('unexpected parse error'));
        return AuthBloc(
          mockRepo,
          mockLocalAuth,
          firebaseAuth: mockFirebaseAuth,
          appleSignIn: (_) async => FakeAppleCredential(),
        );
      },
      act: (b) => b.add(const AuthAppleSignInRequested()),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── Google/Apple — currentUser?.email path ──────────────────────────────────

  group('AuthGoogleSignInRequested — currentUser.email assigned', () {
    blocTest<AuthBloc, AuthState>(
      'émet [Loading, Authenticated] et assigne email depuis currentUser',
      build: () {
        final mockGoogleSignIn = MockGoogleSignIn();
        final mockGoogleUser = MockGoogleSignInAccount();
        final mockGoogleAuth = MockGoogleSignInAuthentication();
        final mockFirebaseUser = MockFirebaseUser()
          ..emailValue = 'user@gmail.com';
        when(
          () => mockGoogleSignIn.signIn(),
        ).thenAnswer((_) async => mockGoogleUser);
        when(
          () => mockGoogleUser.authentication,
        ).thenAnswer((_) async => mockGoogleAuth);
        when(() => mockGoogleAuth.accessToken).thenReturn('access');
        when(() => mockGoogleAuth.idToken).thenReturn('id');
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => FakeUserCredential());
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockFirebaseUser);
        when(() => mockRepo.getProfile()).thenAnswer((_) async => testUser);
        return AuthBloc(
          mockRepo,
          mockLocalAuth,
          firebaseAuth: mockFirebaseAuth,
          googleSignIn: mockGoogleSignIn,
        );
      },
      act: (b) => b.add(const AuthGoogleSignInRequested()),
      expect: () => [const AuthLoading(), const AuthAuthenticated(testUser)],
    );
  });

  group('AuthAppleSignInRequested — currentUser.email assigned', () {
    blocTest<AuthBloc, AuthState>(
      'émet [Loading, Authenticated] et assigne email depuis currentUser',
      build: () {
        final mockFirebaseUser = MockFirebaseUser()
          ..emailValue = 'user@icloud.com';
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => FakeUserCredential());
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockFirebaseUser);
        when(() => mockRepo.getProfile()).thenAnswer((_) async => testUser);
        return AuthBloc(
          mockRepo,
          mockLocalAuth,
          firebaseAuth: mockFirebaseAuth,
          appleSignIn: (_) async => FakeAppleCredential(),
        );
      },
      act: (b) => b.add(const AuthAppleSignInRequested()),
      expect: () => [const AuthLoading(), const AuthAuthenticated(testUser)],
    );
  });

  // ─── catch(e) dans _onGoogleSignInRequested et _onAppleSignInRequested ─────

  group('OAuth outer catch(e)', () {
    blocTest<AuthBloc, AuthState>(
      'Google: signIn() throws generic exception → émet [Loading, AuthError]',
      build: () {
        final mockGoogleSignIn = MockGoogleSignIn();
        when(
          () => mockGoogleSignIn.signIn(),
        ).thenThrow(Exception('Google play services unavailable'));
        return AuthBloc(
          mockRepo,
          mockLocalAuth,
          firebaseAuth: mockFirebaseAuth,
          googleSignIn: mockGoogleSignIn,
        );
      },
      act: (b) => b.add(const AuthGoogleSignInRequested()),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );

    blocTest<AuthBloc, AuthState>(
      'Apple: appleSignIn() throws generic exception → émet [Loading, AuthError]',
      build: () => AuthBloc(
        mockRepo,
        mockLocalAuth,
        firebaseAuth: mockFirebaseAuth,
        appleSignIn: (_) async => throw Exception('Apple auth unavailable'),
      ),
      act: (b) => b.add(const AuthAppleSignInRequested()),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── AuthSendOtpRequested — envoi backend (2e passe, cas complémentaires) ────

  group('AuthSendOtpRequested — cas complémentaires', () {
    blocTest<AuthBloc, AuthState>(
      'succès → émet [Loading, AuthOtpSent] avec le bon numéro',
      build: () {
        when(
          () => mockRepo.sendPhoneOtp('+33612345678'),
        ).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthSendOtpRequested('+33612345678')),
      expect: () => [
        const AuthLoading(),
        isA<AuthOtpSent>()
            .having((s) => s.phoneNumber, 'phoneNumber', '+33612345678')
            .having((s) => s.secondsLeft, 'secondsLeft', 60),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'échec backend → émet [Loading, AuthError]',
      build: () {
        when(
          () => mockRepo.sendPhoneOtp(any()),
        ).thenThrow(Exception('invalid-phone-number'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthSendOtpRequested('+33000')),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── AuthUpdateProfileRequested — champs étendus (bio/languages/transportMode) ──

  group('AuthUpdateProfileRequested — champs étendus', () {
    blocTest<AuthBloc, AuthState>(
      'emits AuthProfileUpdated with bio/languages/transport',
      build: () {
        const updatedUser = UserModel(
          id: 'user-123',
          roles: ['SENDER'],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
          bio: 'X',
        );
        when(
          () => mockRepo.updateProfile(
            bio: any(named: 'bio'),
            languages: any(named: 'languages'),
            transportMode: any(named: 'transportMode'),
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            birthDate: any(named: 'birthDate'),
            city: any(named: 'city'),
            phoneNumber: any(named: 'phoneNumber'),
          ),
        ).thenAnswer((_) async => updatedUser);
        return buildBloc();
      },
      act: (b) => b.add(
        const AuthUpdateProfileRequested(
          bio: 'X',
          languages: ['FR'],
          transportMode: 'AVION',
        ),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthProfileUpdated>()],
      verify: (bloc) {
        verify(
          () => mockRepo.updateProfile(
            bio: 'X',
            languages: ['FR'],
            transportMode: 'AVION',
          ),
        ).called(1);
      },
    );
  });

  // ─── AuthAvatarUploadRequested ────────────────────────────────────────────────

  group('AuthAvatarUploadRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits AuthProfileUpdated on avatar upload',
      build: () {
        const updatedUser = UserModel(
          id: 'user-123',
          roles: ['SENDER'],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
          avatarUrl: 'https://cdn/a.jpg',
        );
        when(
          () => mockRepo.uploadAvatar(any()),
        ).thenAnswer((_) async => updatedUser);
        return buildBloc();
      },
      act: (b) => b.add(const AuthAvatarUploadRequested('/tmp/a.jpg')),
      expect: () => [isA<AuthLoading>(), isA<AuthProfileUpdated>()],
      verify: (bloc) {
        verify(() => mockRepo.uploadAvatar('/tmp/a.jpg')).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthError on avatar upload failure',
      build: () {
        when(
          () => mockRepo.uploadAvatar(any()),
        ).thenThrow(Exception('Upload failed'));
        return buildBloc();
      },
      act: (b) => b.add(const AuthAvatarUploadRequested('/tmp/a.jpg')),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );
  });
}
