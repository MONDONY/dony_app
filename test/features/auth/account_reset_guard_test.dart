import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/account_reset_guard.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _makeUser() => const UserModel(
  id: 'uid-1',
  roles: ['ROLE_SENDER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

void main() {
  group('AccountResetGuard.shouldResetAccountScopedBlocs', () {
    test('AuthNewAccountAuthenticated → true (nouvelle inscription, '
        'AuthBloc._clearHiveAccountData déjà appelé)', () {
      expect(
        AccountResetGuard.shouldResetAccountScopedBlocs(
          AuthNewAccountAuthenticated(_makeUser()),
        ),
        isTrue,
      );
    });

    test('AuthAccountDeleted → true (suppression de compte, '
        'AuthBloc._clearHiveAccountData déjà appelé)', () {
      expect(
        AccountResetGuard.shouldResetAccountScopedBlocs(
          const AuthAccountDeleted(),
        ),
        isTrue,
      );
    });

    test('AuthInitial → true (déconnexion ou changement de compte — aussi '
        'l\'état de démarrage, mais réagir y est sans risque : le reset est '
        'idempotent)', () {
      expect(
        AccountResetGuard.shouldResetAccountScopedBlocs(const AuthInitial()),
        isTrue,
      );
    });

    test('AuthAuthenticated (compte existant, pas nouveau) → false — ce '
        'n\'est pas une purge, un simple login ne doit pas jeter les données '
        'déjà chargées', () {
      expect(
        AccountResetGuard.shouldResetAccountScopedBlocs(
          AuthAuthenticated(_makeUser()),
        ),
        isFalse,
      );
    });

    test('AuthLoading → false', () {
      expect(
        AccountResetGuard.shouldResetAccountScopedBlocs(const AuthLoading()),
        isFalse,
      );
    });

    test('AuthProfileUpdated → false', () {
      expect(
        AccountResetGuard.shouldResetAccountScopedBlocs(
          AuthProfileUpdated(_makeUser()),
        ),
        isFalse,
      );
    });

    test('AuthGuestSessionReady → false (session invitée, pas une purge)', () {
      expect(
        AccountResetGuard.shouldResetAccountScopedBlocs(
          const AuthGuestSessionReady(),
        ),
        isFalse,
      );
    });

    test('AuthError → false', () {
      expect(
        AccountResetGuard.shouldResetAccountScopedBlocs(
          const AuthError(NetworkException('erreur réseau')),
        ),
        isFalse,
      );
    });
  });
}
