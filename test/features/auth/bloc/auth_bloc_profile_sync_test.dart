import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/apple_token_revoker.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockLocalAuthService extends Mock implements LocalAuthService {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

const _user = UserModel(
  id: 'user-123',
  phoneNumber: '+33612345678',
  roles: ['SENDER'],
  kycStatus: 'PENDING',
  status: 'ACTIVE',
);

void main() {
  late _MockAuthRepository repo;

  setUp(() => repo = _MockAuthRepository());

  AuthBloc build() => AuthBloc(
    repo,
    _MockLocalAuthService(),
    firebaseAuth: _MockFirebaseAuth(),
    appleTokenRevoker: AppleTokenRevoker(
      providerIds: () => const ['phone'],
      isApplePlatform: () => false,
      fetchAuthorizationCode: () async => null,
      revoke: (_) async {},
    ),
  );

  blocTest<AuthBloc, AuthState>(
    'AuthUserSynced → profil mis à jour sans appel réseau',
    build: build,
    act: (b) => b.add(const AuthUserSynced(_user)),
    expect: () => [
      isA<AuthProfileUpdated>().having((s) => s.user.id, 'user.id', 'user-123'),
    ],
    verify: (_) => verifyZeroInteractions(repo),
  );

  blocTest<AuthBloc, AuthState>(
    'rafraîchissement du profil → profil relu sur le serveur',
    build: () {
      when(() => repo.getProfile()).thenAnswer((_) async => _user);
      return build();
    },
    act: (b) => b.add(const AuthProfileRefreshRequested()),
    expect: () => [isA<AuthProfileUpdated>()],
    verify: (_) => verify(() => repo.getProfile()).called(1),
  );

  blocTest<AuthBloc, AuthState>(
    'rafraîchissement du profil en échec → silencieux, aucun état d’erreur',
    build: () {
      when(() => repo.getProfile()).thenThrow(const ServerException());
      return build();
    },
    act: (b) => b.add(const AuthProfileRefreshRequested()),
    expect: () => <AuthState>[],
  );
}
