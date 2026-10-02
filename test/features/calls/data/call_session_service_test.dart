import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/calls/data/call_session_service.dart';
import 'package:dony/features/calls/data/models/call_token.dart';
import 'package:dony/features/calls/data/repositories/calls_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_call_gateway.dart';

class _MockCallsRepository extends Mock implements CallsRepository {}

CallToken _token(String userId, {String token = 't1'}) => CallToken(
  apiKey: 'key',
  userId: userId,
  token: token,
  expiresAt: DateTime.utc(2026, 10, 3),
);

const _awa = UserModel(
  id: 'u1',
  firstName: 'Awa',
  lastName: 'Diop',
  avatarUrl: 'https://img/awa.png',
  roles: [],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

const _moussa = UserModel(id: 'u2', firstName: 'Moussa', roles: [], kycStatus: 'VERIFIED', status: 'ACTIVE');

void main() {
  late _MockCallsRepository repository;
  late FakeCallGateway gateway;
  late CallSessionService service;

  setUp(() {
    repository = _MockCallsRepository();
    gateway = FakeCallGateway();
    service = CallSessionService(repository, gateway);
  });

  tearDown(() => gateway.dispose());

  test('connexion avec le nom public (prénom + initiale), jamais le nom complet', () async {
    when(() => repository.fetchToken()).thenAnswer((_) async => _token('u1'));

    await service.onSignedIn(_awa);

    expect(gateway.log, ['connect:key:u1:Awa D.']);
    expect(gateway.isConnected, isTrue);
  });

  test('le chargeur de jeton redemande un jeton au back', () async {
    when(() => repository.fetchToken()).thenAnswer((_) async => _token('u1', token: 't2'));

    await service.onSignedIn(_awa);

    expect(await gateway.tokenLoader!(), 't2');
    verify(() => repository.fetchToken()).called(2);
  });

  test('même compte connecté deux fois : une seule connexion', () async {
    when(() => repository.fetchToken()).thenAnswer((_) async => _token('u1'));

    await service.onSignedIn(_awa);
    await service.onSignedIn(_awa);

    expect(gateway.log.where((l) => l.startsWith('connect')), hasLength(1));
  });

  test('autre compte : déconnexion puis connexion', () async {
    when(() => repository.fetchToken()).thenAnswer((_) async => _token('u1'));
    await service.onSignedIn(_awa);
    when(() => repository.fetchToken()).thenAnswer((_) async => _token('u2'));

    await service.onSignedIn(_moussa);

    expect(gateway.log, ['connect:key:u1:Awa D.', 'disconnect', 'connect:key:u2:Moussa']);
  });

  test('déconnexion du compte', () async {
    when(() => repository.fetchToken()).thenAnswer((_) async => _token('u1'));
    await service.onSignedIn(_awa);

    await service.onSignedOut();

    expect(gateway.log.last, 'disconnect');
    expect(gateway.isConnected, isFalse);
  });

  test('déconnexion sans session : rien', () async {
    await service.onSignedOut();
    expect(gateway.log, isEmpty);
  });

  test('appels coupés côté back (503) : pas de connexion, pas d\'exception', () async {
    when(() => repository.fetchToken()).thenThrow(const ServerException('off', 'calls-disabled'));

    await service.onSignedIn(_awa);

    expect(gateway.log, isEmpty);
  });

  test('échec de connexion Stream : avalé, nouvelle tentative au prochain login', () async {
    when(() => repository.fetchToken()).thenAnswer((_) async => _token('u1'));
    gateway.throwOnConnect = StateError('ko');

    await service.onSignedIn(_awa);
    gateway.throwOnConnect = null;
    await service.onSignedIn(_awa);

    expect(gateway.isConnected, isTrue);
  });

  group('syncCallSession', () {
    test('connecté : session ouverte', () async {
      when(() => repository.fetchToken()).thenAnswer((_) async => _token('u1'));
      await syncCallSession(const AuthAuthenticated(_awa), service);
      expect(gateway.isConnected, isTrue);
    });

    test('déconnexion ou compte supprimé : session fermée', () async {
      when(() => repository.fetchToken()).thenAnswer((_) async => _token('u1'));
      await syncCallSession(const AuthAuthenticated(_awa), service);
      await syncCallSession(const AuthInitial(), service);
      expect(gateway.isConnected, isFalse);

      await syncCallSession(const AuthAuthenticated(_awa), service);
      await syncCallSession(const AuthAccountDeleted(), service);
      expect(gateway.isConnected, isFalse);
    });

    test('états transitoires : rien ne change', () async {
      await syncCallSession(const AuthLoading(), service);
      expect(gateway.log, isEmpty);
    });
  });
}
