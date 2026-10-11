// Constructeurs appelés à l'exécution : un appel `const` n'est jamais exécuté
// et deux instances `const` identiques court-circuitent la comparaison.
// ignore_for_file: prefer_const_constructors

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/local_auth_event.dart';
import 'package:dony/features/auth/bloc/local_auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/value_equality.dart';

UserModel _user(String id) => UserModel(
  id: id,
  roles: const ['SENDER'],
  kycStatus: 'NONE',
  status: 'ACTIVE',
);

void main() {
  group('AuthEvent — égalité de valeur', () {
    test('événements sans champ : égaux entre eux, distincts par type', () {
      expectValueEquality(() => AuthSwitchAccountRequested(), [
        AuthLogoutRequested(),
      ]);
      expectValueEquality(() => AuthGoogleSignInRequested(), [
        AuthAppleSignInRequested(),
      ]);
      expectValueEquality(() => AuthAppleSignInRequested(), [
        AuthGoogleSignInRequested(),
      ]);
      expectValueEquality(() => AuthProfileRefreshRequested(), [
        AuthGuestSessionRequested(),
      ]);
      expectValueEquality(() => AuthGuestSessionRequested(), [
        AuthCheckRequested(),
      ]);
      expect(AuthGuestSessionRequested().props, isEmpty);
    });

    test('ajout de téléphone ou d’email depuis le profil : valeur et code', () {
      expectValueEquality(
        () => AuthAddPhoneFromProfileRequested(
          phoneNumber: '+221770000000',
          code: '123456',
        ),
        [
          AuthAddPhoneFromProfileRequested(
            phoneNumber: '+221770000000',
            code: '654321',
          ),
        ],
      );
      expectValueEquality(
        () => AuthAddEmailFromProfileRequested(email: 'a@b.sn', code: '1'),
        [
          AuthAddEmailFromProfileRequested(email: 'c@d.sn', code: '1'),
          AuthEmailOtpVerifyRequested(email: 'a@b.sn', code: '1'),
        ],
      );
    });

    test('AuthUserSynced compare l’utilisateur synchronisé', () {
      expectValueEquality(() => AuthUserSynced(_user('u-1')), [
        AuthUserSynced(_user('u-2')),
      ]);
    });
  });

  group('LocalAuthEvent', () {
    test('chaque événement est un LocalAuthEvent, le PIN est conservé', () {
      final events = <LocalAuthEvent>[
        LocalAuthStarted(),
        LocalAuthBiometricRequested(),
        LocalAuthPinSubmitted('1234'),
        LocalAuthLockExpired(),
      ];
      expect(events.map((e) => e.runtimeType).toSet(), hasLength(4));
      expect((events[2] as LocalAuthPinSubmitted).pin, '1234');
    });
  });

  group('LocalAuthState — égalité de valeur', () {
    test('états sans champ et état d’erreur', () {
      expectValueEquality(() => LocalAuthInitial(), [LocalAuthChecking()]);
      expectValueEquality(
        () => LocalAuthError(const NetworkException('réseau')),
        [LocalAuthError(const ServerException())],
      );
    });
  });
}
