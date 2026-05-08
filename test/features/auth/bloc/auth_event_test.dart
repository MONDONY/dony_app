// ignore_for_file: prefer_const_constructors
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthSendOtpRequested', () {
    test('props contains phoneNumber', () {
      final e = AuthSendOtpRequested('+33612345678');
      expect(e.props, ['+33612345678']);
    });

    test('equality', () {
      expect(AuthSendOtpRequested('+33'), AuthSendOtpRequested('+33'));
    });
  });

  group('AuthPhoneVerified', () {
    test('props contains all fields', () {
      final e = AuthPhoneVerified(verificationId: 'v1', smsCode: '123', autoVerified: true);
      expect(e.props, ['v1', '123', true]);
    });

    test('default autoVerified is false', () {
      final e = AuthPhoneVerified(verificationId: 'v1', smsCode: '123');
      expect(e.props, ['v1', '123', false]);
    });
  });

  group('AuthRegisterRequested', () {
    test('props is empty', () {
      final e = AuthRegisterRequested();
      expect(e.props, isEmpty);
    });

    test('equality', () {
      expect(AuthRegisterRequested(), AuthRegisterRequested());
    });
  });

  group('AuthCheckRequested', () {
    test('props is empty', () {
      expect(AuthCheckRequested().props, isEmpty);
    });
  });

  group('AuthLogoutRequested', () {
    test('props is empty', () {
      expect(AuthLogoutRequested().props, isEmpty);
    });
  });

  group('AuthDeleteAccountRequested', () {
    test('props is empty', () {
      expect(AuthDeleteAccountRequested().props, isEmpty);
    });
  });

  group('AuthUpdateProfileRequested', () {
    test('props contains all fields', () {
      final date = DateTime(1990, 5, 15);
      final e = AuthUpdateProfileRequested(
        firstName: 'Amadou',
        lastName: 'Diallo',
        email: 'a@d.com',
        birthDate: date,
        city: 'Paris',
      );
      expect(e.props, ['Amadou', 'Diallo', 'a@d.com', date, 'Paris']);
    });

    test('props with null fields', () {
      final e = AuthUpdateProfileRequested();
      expect(e.props, [null, null, null, null, null]);
    });
  });

  group('OnboardingCompleted', () {
    test('props is empty', () {
      expect(OnboardingCompleted().props, isEmpty);
    });
  });

  group('AuthDialCodeChanged', () {
    test('props contains code and flag', () {
      final e = AuthDialCodeChanged(code: '+33', flag: '🇫🇷');
      expect(e.props, ['+33', '🇫🇷']);
    });

    test('equality', () {
      expect(
        AuthDialCodeChanged(code: '+221', flag: '🇸🇳'),
        AuthDialCodeChanged(code: '+221', flag: '🇸🇳'),
      );
    });
  });
}
