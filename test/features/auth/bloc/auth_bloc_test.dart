import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthRegisterRequested(['SENDER'])),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAuthenticated>(),
      ],
      verify: (bloc) {
        verify(() => mockRepo.register(
              phoneNumber: any(named: 'phoneNumber'),
              roles: any(named: 'roles'),
            )).called(1);
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
      act: (bloc) => bloc.add(const AuthRegisterRequested(['SENDER'])),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>((s) =>
            s is AuthError && s.message == 'Ce numéro est déjà associé à un compte'),
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
      act: (bloc) => bloc.add(const AuthRegisterRequested(['TRAVELER'])),
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
      const state = AuthOtpSent(
        verificationId: 'ver-123',
        phoneNumber: '+33612345678',
      );
      expect(state.props, containsAllInOrder(['ver-123', '+33612345678']));
    });
  });
}
