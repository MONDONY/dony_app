import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/kyc/data/kyc_recheck.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAuthBloc extends Mock implements AuthBloc {}

UserModel _user(String kyc) => UserModel.fromJson({
  'id': 'u1',
  'roles': const ['SENDER', 'TRAVELER'],
  'kycStatus': kyc,
});

void main() {
  late _MockAuthRepository repo;
  late _MockAuthBloc bloc;

  setUpAll(() => registerFallbackValue(const AuthProfileRefreshRequested()));

  setUp(() {
    repo = _MockAuthRepository();
    bloc = _MockAuthBloc();
    when(() => bloc.isClosed).thenReturn(false);
    when(() => bloc.add(any())).thenReturn(null);
    getIt.registerSingleton<AuthRepository>(repo);
  });
  tearDown(getIt.reset);

  test('serveur VERIFIED : true et profil resynchronisé', () async {
    when(() => repo.getProfile()).thenAnswer((_) async => _user('VERIFIED'));
    expect(await recheckKycVerified(bloc), isTrue);
    final event =
        verify(() => bloc.add(captureAny())).captured.single as AuthUserSynced;
    expect(event.user.isKycVerified, isTrue);
  });

  test('serveur non vérifié : false', () async {
    when(() => repo.getProfile()).thenAnswer((_) async => _user('PENDING'));
    expect(await recheckKycVerified(bloc), isFalse);
  });

  test('erreur réseau : false, sans exception', () async {
    when(() => repo.getProfile()).thenThrow(Exception('hors ligne'));
    expect(await recheckKycVerified(bloc), isFalse);
    verifyNever(() => bloc.add(any()));
  });

  test('délai dépassé : false', () async {
    when(() => repo.getProfile()).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return _user('VERIFIED');
    });
    expect(
      await recheckKycVerified(bloc, timeout: const Duration(milliseconds: 10)),
      isFalse,
    );
  });

  test('bloc fermé : pas d\'ajout d\'événement', () async {
    when(() => bloc.isClosed).thenReturn(true);
    when(() => repo.getProfile()).thenAnswer((_) async => _user('VERIFIED'));
    expect(await recheckKycVerified(bloc), isTrue);
    verifyNever(() => bloc.add(any()));
  });

  test('dépôt non enregistré : false', () async {
    await getIt.reset();
    expect(await recheckKycVerified(bloc), isFalse);
  });
}
