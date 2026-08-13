// ignore_for_file: prefer_const_constructors
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthStateUser extension', () {
    const user = UserModel(
      id: 'user-123',
      roles: ['ROLE_TRAVELER'],
      kycStatus: 'VERIFIED',
      status: 'ACTIVE',
    );

    test('currentUser/currentUserId résolus pour AuthAuthenticated', () {
      const state = AuthAuthenticated(user);
      expect(state.currentUser, user);
      expect(state.currentUserId, 'user-123');
    });

    // Cœur de la régression : après upload avatar / édition profil, le bloc
    // émet AuthProfileUpdated. La détection « c'est mon trajet » doit continuer
    // à trouver l'ID utilisateur, sinon les cartes du propriétaire repassent en
    // cartes standard (cœur favori affiché, pas de pastille « Votre trajet »).
    test('currentUser/currentUserId résolus pour AuthProfileUpdated', () {
      const state = AuthProfileUpdated(user);
      expect(state.currentUser, user);
      expect(state.currentUserId, 'user-123');
    });

    test('currentUser null pour les états non connectés', () {
      expect(const AuthInitial().currentUser, isNull);
      expect(const AuthLoading().currentUserId, isNull);
      expect(const AuthLocked().currentUserId, isNull);
    });
  });

  group('AuthOtpSent', () {
    test('copyWith replaces secondsLeft', () {
      final state = AuthOtpSent(
        verificationId: 'v1',
        phoneNumber: '+33612345678',
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
