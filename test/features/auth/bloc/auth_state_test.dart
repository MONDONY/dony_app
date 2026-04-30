// ignore_for_file: prefer_const_constructors
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthOtpSent', () {
    test('copyWith replaces secondsLeft', () {
      final state = AuthOtpSent(
        verificationId: 'v1',
        phoneNumber: '+33612345678',
        secondsLeft: 60,
      );
      final updated = state.copyWith(secondsLeft: 30);
      expect(updated.secondsLeft, 30);
      expect(updated.verificationId, 'v1');
      expect(updated.phoneNumber, '+33612345678');
    });

    test('copyWith preserves secondsLeft when not passed', () {
      final state = AuthOtpSent(
        verificationId: 'v2',
        phoneNumber: '+221761234567',
        secondsLeft: 45,
      );
      final same = state.copyWith();
      expect(same.secondsLeft, 45);
    });
  });
}
