import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthEmailOtpSendRequested', () {
    test('props contient email', () {
      const e = AuthEmailOtpSendRequested('a@b.com');
      expect(e.props, ['a@b.com']);
    });
  });

  group('AuthEmailOtpVerifyRequested', () {
    test('props contient email et code', () {
      const e = AuthEmailOtpVerifyRequested(email: 'a@b.com', code: '123456');
      expect(e.props, ['a@b.com', '123456']);
    });
  });

  group('AuthRegisterWithEmailRequested', () {
    test('props contient email', () {
      const e = AuthRegisterWithEmailRequested(email: 'a@b.com');
      expect(e.props, ['a@b.com']);
    });
  });

  group('AuthEmailOtpSent', () {
    test('copyWith met à jour secondsLeft', () {
      const s = AuthEmailOtpSent('a@b.com');
      expect(s.copyWith(secondsLeft: 30).secondsLeft, 30);
      expect(s.copyWith(secondsLeft: 30).email, 'a@b.com');
    });
  });

  group('AuthEmailOtpVerified', () {
    test('props contient email', () {
      const s = AuthEmailOtpVerified('a@b.com');
      expect(s.props, ['a@b.com']);
    });
  });

  group('AuthOAuthNewUser', () {
    test('props contient email', () {
      const s = AuthOAuthNewUser('a@b.com');
      expect(s.props, ['a@b.com']);
    });
  });
}
