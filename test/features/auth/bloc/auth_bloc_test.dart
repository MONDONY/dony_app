import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class MockAuthRepository extends Mock implements AuthRepository {}
class MockLocalAuthService extends Mock implements LocalAuthService {}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}
class MockUserCredential extends Mock implements UserCredential {}
class MockPhoneAuthCredential extends Mock implements PhoneAuthCredential {}

// ─── Fake pour PhoneAuthCredential ────────────────────────────────────────────

class FakeAuthCredential extends Fake implements AuthCredential {}
class FakePhoneAuthCredential extends Fake implements PhoneAuthCredential {}

class FakeUserCredential extends Fake implements UserCredential {}

class MockFirebaseUser extends Mock implements User {
  String emailValue = '';
  @override
  String? get email => emailValue;
}

// Google mocks
class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}
class MockGoogleSignInAuthentication extends Mock implements GoogleSignInAuthentication {}

// Apple fake
class FakeAppleCredential extends Fake implements AuthorizationCredentialAppleID {
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

  const testUser = UserModel(
    id: 'user-123',
    phoneNumber: '+33612345678',
    roles: ['SENDER'],
    kycStatus: 'PENDING',
    status: 'ACTIVE',
  );

  setUpAll(() {
    registerFallbackValue(FakeAuthCredential());
    registerFallbackValue(FakePhoneAuthCredential());
  });

  setUp(() {
    mockRepo = MockAuthRepository();
    mockLocalAuth = MockLocalAuthService();
    mockFirebaseAuth = MockFirebaseAuth();
  });

  AuthBloc buildBloc() => AuthBloc(
        mockRepo,
        mockLocalAuth,
        firebaseAuth: mockFirebaseAuth,
      );

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
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAuthenticated>(),
      ],
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
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthInitial>(),
      ],
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
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>(),
      ],
    );
  });

  // ─── AuthRegisterRequested ───────────────────────────────────────────────────

  group('AuthRegisterRequested', () {
    blocTest<AuthBloc, AuthState>(
      'inscription réussie → émet AuthAuthenticated avec user',
      build: () {
        when(() => mockRepo.register(
              phoneNumber: any(named: 'phoneNumber'),
              roles: any(named: 'roles'),
            )).thenAnswer((_) async => testUser);
        when(() => mockLocalAuth.clearPin()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthRegisterRequested()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAuthenticated>(),
      ],
      verify: (bloc) {
        verify(() => mockRepo.register(
              phoneNumber: any(named: 'phoneNumber'),
              roles: ['TRAVELER', 'SENDER'],
            )).called(1);
        verify(() => mockLocalAuth.clearPin()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'numéro déjà utilisé → émet AuthError avec message localisé',
      build: () {
        when(() => mockRepo.register(
              phoneNumber: any(named: 'phoneNumber'),
              roles: any(named: 'roles'),
            )).thenThrow(Exception('Ce numéro est déjà associé à un compte'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthRegisterRequested()),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>((s) =>
            s is AuthError && s.error.message == 'Ce numéro est déjà associé à un compte'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'erreur générique → émet AuthError',
      build: () {
        when(() => mockRepo.register(
              phoneNumber: any(named: 'phoneNumber'),
              roles: any(named: 'roles'),
            )).thenThrow(Exception('Server error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthRegisterRequested()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>(),
      ],
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
      expect: () => [isA<AuthInitial>()],
      verify: (bloc) {
        verify(() => mockFirebaseAuth.signOut()).called(1);
        // clearPin() ne doit PAS être appelé lors d'un logout simple
        verifyNever(() => mockLocalAuth.clearPin());
      },
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
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAccountDeleted>(),
      ],
      verify: (bloc) {
        verify(() => mockRepo.deleteAccount()).called(1);
        verify(() => mockLocalAuth.clearPin()).called(1);
        verify(() => mockFirebaseAuth.signOut()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'erreur suppression → émet AuthError',
      build: () {
        when(() => mockRepo.deleteAccount())
            .thenThrow(Exception('Erreur suppression'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthDeleteAccountRequested()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>(),
      ],
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
          email: 'amadou@dony.app',
          roles: ['SENDER'],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        when(() => mockRepo.updateProfile(
              firstName: any(named: 'firstName'),
              lastName: any(named: 'lastName'),
              email: any(named: 'email'),
              birthDate: any(named: 'birthDate'),
              city: any(named: 'city'),
            )).thenAnswer((_) async => updatedUser);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthUpdateProfileRequested(
        firstName: 'Amadou',
        lastName: 'Diallo',
        email: 'amadou@dony.app',
      )),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>((s) =>
            s is AuthProfileUpdated && s.user.firstName == 'Amadou'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'erreur mise à jour → émet AuthError',
      build: () {
        when(() => mockRepo.updateProfile(
              firstName: any(named: 'firstName'),
              lastName: any(named: 'lastName'),
              email: any(named: 'email'),
              birthDate: any(named: 'birthDate'),
              city: any(named: 'city'),
            )).thenThrow(Exception('Erreur serveur'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthUpdateProfileRequested(firstName: 'Amadou')),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>(),
      ],
    );
  });

  // ─── AuthPhoneVerified ───────────────────────────────────────────────────────

  group('AuthPhoneVerified', () {
    blocTest<AuthBloc, AuthState>(
      'compte existant → émet [Loading, AuthAuthenticated]',
      build: () {
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenAnswer((_) async => testUser);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthPhoneVerified(
        verificationId: 'ver-abc',
        smsCode: '123456',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAuthenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'nouveau numéro (404) → émet [Loading, AuthOtpVerified]',
      build: () {
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/auth/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/me'),
            statusCode: 404,
          ),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthPhoneVerified(
        verificationId: 'ver-abc',
        smsCode: '123456',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthOtpVerified>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'erreur backend non-404 → émet [Loading, AuthError]',
      build: () {
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/auth/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/me'),
            statusCode: 500,
          ),
        ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthPhoneVerified(
        verificationId: 'ver-abc',
        smsCode: '123456',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'autoVerified=true contourne signInWithCredential',
      build: () {
        when(() => mockRepo.getProfile()).thenAnswer((_) async => testUser);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthPhoneVerified(
        verificationId: '',
        smsCode: '',
        autoVerified: true,
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAuthenticated>(),
      ],
      verify: (_) {
        verifyNever(() => mockFirebaseAuth.signInWithCredential(any()));
      },
    );

    blocTest<AuthBloc, AuthState>(
      'FirebaseAuthException (code invalide) → émet AuthError localisé',
      build: () {
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenThrow(FirebaseAuthException(code: 'invalid-verification-code'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthPhoneVerified(
        verificationId: 'ver-abc',
        smsCode: '000000',
      )),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>((s) =>
            s is AuthError &&
            s.error.message.contains('Code de vérification incorrect')),
      ],
    );
  });

  // ─── AuthPhoneVerified — cas non couverts ────────────────────────────────────

  group('AuthPhoneVerified — erreurs supplémentaires', () {
    blocTest<AuthBloc, AuthState>(
      'getProfile lance exception générique → émet AuthOtpVerified',
      build: () {
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenThrow(Exception('parse error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthPhoneVerified(
        verificationId: 'ver-abc',
        smsCode: '123456',
      )),
      expect: () => [isA<AuthLoading>(), isA<AuthOtpVerified>()],
    );

    blocTest<AuthBloc, AuthState>(
      'signInWithCredential lance Exception générique → émet AuthError',
      build: () {
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenThrow(Exception('unexpected sign-in error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthPhoneVerified(
        verificationId: 'ver-abc',
        smsCode: '123456',
      )),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );

    blocTest<AuthBloc, AuthState>(
      'FirebaseAuthException code-expired → message localisé',
      build: () {
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenThrow(FirebaseAuthException(code: 'code-expired'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthPhoneVerified(
        verificationId: 'ver-abc',
        smsCode: '111111',
      )),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>((s) => s is AuthError && s.error.message.contains('expiré')),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'FirebaseAuthException too-many-requests → message localisé',
      build: () {
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenThrow(FirebaseAuthException(code: 'too-many-requests'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthPhoneVerified(
        verificationId: 'ver-abc',
        smsCode: '111111',
      )),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>((s) => s is AuthError && s.error.message.contains('Trop')),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'FirebaseAuthException session-expired → message localisé',
      build: () {
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenThrow(FirebaseAuthException(code: 'session-expired'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthPhoneVerified(
        verificationId: 'ver-abc',
        smsCode: '111111',
      )),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>((s) => s is AuthError && s.error.message.contains('Session')),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'FirebaseAuthException code inconnu → message.message fallback',
      build: () {
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenThrow(FirebaseAuthException(
              code: 'unknown-error',
              message: 'Custom firebase error',
            ));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthPhoneVerified(
        verificationId: 'ver-abc',
        smsCode: '111111',
      )),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>((s) => s is AuthError && s.error.message == 'Custom firebase error'),
      ],
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
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthInitial>(),
      ],
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
      final s1 = AuthAuthenticated(testUser);
      final s2 = AuthAuthenticated(testUser);
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
      act: (bloc) => bloc.add(
        const AuthDialCodeChanged(code: '+221', flag: '🇸🇳'),
      ),
      expect: () => [
        const AuthInitial(dialCode: '+221', dialFlag: '🇸🇳'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'preserves dial code when emitted from error state',
      build: buildBloc,
      seed: () => AuthError(NetworkException('Erreur réseau')),
      act: (bloc) => bloc.add(
        const AuthDialCodeChanged(code: '+237', flag: '🇨🇲'),
      ),
      expect: () => [
        const AuthInitial(dialCode: '+237', dialFlag: '🇨🇲'),
      ],
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
        secondsLeft: 60,
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

      when(() => mockGoogleSignIn.signIn())
          .thenAnswer((_) async => mockGoogleAccount);
      when(() => mockGoogleAccount.authentication)
          .thenAnswer((_) async => mockGoogleAuth);
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
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenAnswer((_) async => testUser);
      },
      act: (b) => b.add(const AuthGoogleSignInRequested()),
      expect: () => [const AuthLoading(), AuthAuthenticated(testUser)],
    );

    blocTest<AuthBloc, AuthState>(
      'émet [Loading, AuthOAuthNewUser] quand nouveau compte (404)',
      build: () {
        final mockGoogleUser = MockGoogleSignInAccount();
        final mockGoogleAuth = MockGoogleSignInAuthentication();
        final mockGoogleSignIn = MockGoogleSignIn();
        final mockFirebaseUser = MockFirebaseUser()..emailValue = 'newuser@gmail.com';
        when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleUser);
        when(() => mockGoogleUser.authentication).thenAnswer((_) async => mockGoogleAuth);
        when(() => mockGoogleAuth.accessToken).thenReturn('access');
        when(() => mockGoogleAuth.idToken).thenReturn('id');
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => FakeUserCredential());
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockFirebaseUser);
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ''),
            response: Response(
              statusCode: 404,
              requestOptions: RequestOptions(path: ''),
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
        isA<AuthOAuthNewUser>().having((s) => s.email, 'email', 'newuser@gmail.com'),
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
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ''),
            response: Response(
              statusCode: 500,
              requestOptions: RequestOptions(path: ''),
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
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenAnswer((_) async => testUser);
      },
      act: (b) => b.add(const AuthAppleSignInRequested()),
      expect: () => [const AuthLoading(), AuthAuthenticated(testUser)],
    );

    blocTest<AuthBloc, AuthState>(
      'émet [Loading, AuthOAuthNewUser] quand nouveau compte (404)',
      build: () {
        final mockFirebaseUser = MockFirebaseUser()..emailValue = 'newaple@icloud.com';
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => FakeUserCredential());
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockFirebaseUser);
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ''),
            response: Response(
              statusCode: 404,
              requestOptions: RequestOptions(path: ''),
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
        isA<AuthOAuthNewUser>().having((s) => s.email, 'email', 'newaple@icloud.com'),
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
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ''),
            response: Response(
              statusCode: 500,
              requestOptions: RequestOptions(path: ''),
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
        when(() => mockRepo.sendEmailOtp('a@b.com'))
            .thenAnswer((_) async {});
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
        when(() => mockRepo.sendEmailOtp(any()))
            .thenThrow(Exception('network error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthEmailOtpSendRequested('a@b.com')),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── AuthEmailOtpVerifyRequested ─────────────────────────────────────────────

  group('AuthEmailOtpVerifyRequested', () {
    blocTest<AuthBloc, AuthState>(
      'émet [AuthLoading, AuthEmailOtpVerified] en cas de succès',
      build: () {
        when(() => mockRepo.verifyEmailOtp('a@b.com', '123456'))
            .thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthEmailOtpVerifyRequested(email: 'a@b.com', code: '123456')),
      expect: () => [
        const AuthLoading(),
        isA<AuthEmailOtpVerified>().having((s) => s.email, 'email', 'a@b.com'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'émet [AuthLoading, AuthError] si code invalide',
      build: () {
        when(() => mockRepo.verifyEmailOtp(any(), any()))
            .thenThrow(Exception('invalid code'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthEmailOtpVerifyRequested(email: 'a@b.com', code: '000000')),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );
  });

  // ─── AuthRegisterWithEmailRequested ──────────────────────────────────────────

  group('AuthRegisterWithEmailRequested', () {
    blocTest<AuthBloc, AuthState>(
      'émet [AuthLoading, AuthAuthenticated] en cas de succès',
      build: () {
        when(() => mockRepo.registerWithEmail(
                email: 'a@b.com', roles: ['SENDER']))
            .thenAnswer((_) async => testUser);
        when(() => mockLocalAuth.clearPin()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthRegisterWithEmailRequested(email: 'a@b.com', roles: ['SENDER']),
      ),
      expect: () => [
        const AuthLoading(),
        isA<AuthAuthenticated>(),
      ],
      verify: (_) {
        verify(() => mockLocalAuth.clearPin()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'émet [AuthLoading, AuthError] si register échoue',
      build: () {
        when(() => mockRepo.registerWithEmail(
                email: any(named: 'email'), roles: any(named: 'roles')))
            .thenThrow(Exception('email already exists'));
        when(() => mockLocalAuth.clearPin()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthRegisterWithEmailRequested(email: 'a@b.com', roles: ['SENDER']),
      ),
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
        final mockFirebaseUser = MockFirebaseUser()..emailValue = 'test@gmail.com';
        when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleUser);
        when(() => mockGoogleUser.authentication).thenAnswer((_) async => mockGoogleAuth);
        when(() => mockGoogleAuth.accessToken).thenReturn('access');
        when(() => mockGoogleAuth.idToken).thenReturn('id');
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => FakeUserCredential());
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
        isA<AuthOAuthNewUser>().having((s) => s.email, 'email', 'test@gmail.com'),
      ],
    );
  });
}
