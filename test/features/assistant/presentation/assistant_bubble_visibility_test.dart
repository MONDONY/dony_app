import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/assistant/presentation/assistant_bubble_visibility.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('écrans exclus', () {
    for (final p in [
      // Portes : onboarding, mise à jour forcée, authentification, verrou PIN.
      '/onboarding', '/force-update', '/auth/method', '/auth/phone',
      '/auth/local',
      // KYC, onboarding Stripe, comptes bloqués.
      '/kyc/verify', '/kyc/status', '/connect/onboarding/intro',
      '/stripe/onboarding/complete', '/account/disabled', '/account/rejected',
      // Caméra et scan.
      '/tracking/scan', '/tracking/scan/photo', '/tracking/scan/confirm',
      '/tracking/scan-hub', '/tracking/validate',
      // Paiement.
      '/payments/pay', '/payments/wallet/topup/amount', '/payment/confirm',
      '/bids/b1/mobile-money/awaiting',
      '/negotiations/n1/mobile-money/awaiting',
      // Appel, conversations, support, assistant.
      '/calls/abc', '/chat/photo', '/conversations/42', '/support',
      '/support/tickets/t1', '/assistant',
      // Lecteur vidéo des tutoriels.
      '/profile/help/tutorial/abc',
      // Recharge, paiement, onboarding de versement : toujours exclus.
      '/payments/wallet/topup/method', '/payments/wallet/topup/amount',
      '/payments/wallet/topup/mobile-money/awaiting',
      '/payments/commission-method', '/payments/onboarding',
      '/payments/mobile-money/account',
      // Création / changement de code PIN (chemins réels du routeur).
      '/settings/security/change-pin', '/settings/security/create-pin',
    ]) {
      expect(isAssistantBubbleExcludedLocation(p), isTrue, reason: p);
    }
  });

  test('écrans autorisés', () {
    for (final p in [
      '/home',
      '/announcements',
      '/tracking',
      '/messages',
      '/profile',
      '/profile/edit/phone',
      '/trips/create',
      '/settings',
      '/settings/security',
      '/settings/security/devices',
      '/messages/archives',
      '/bids/b1',
      '/negotiations',
      // Portefeuille, historique et « Mon argent » : pas des écrans de
      // paiement.
      '/payments/wallet',
      '/payments/wallet/refunds',
      '/payments/money',
      '/payments/money/trips',
    ]) {
      expect(isAssistantBubbleExcludedLocation(p), isFalse, reason: p);
    }
  });

  test('conditions', () {
    bool show({
      bool signedIn = true,
      bool enabled = true,
      bool disabled = false,
      bool available = true,
      bool keyboardOpen = false,
      String path = '/home',
    }) => shouldShowAssistantBubble(
      path: path,
      signedIn: signedIn,
      enabled: enabled,
      disabled: disabled,
      available: available,
      keyboardOpen: keyboardOpen,
    );
    expect(show(), isTrue);
    expect(show(signedIn: false), isFalse);
    expect(show(enabled: false), isFalse);
    expect(show(disabled: true), isFalse);
    expect(show(available: false), isFalse);
    expect(show(path: ''), isFalse, reason: 'chemin vide : bulle cachée');
    expect(show(keyboardOpen: true), isFalse);
    expect(show(path: '/assistant'), isFalse);
    expect(show(path: '/auth/local'), isFalse);
  });

  group('assistantSignedInAfter', () {
    final user = UserModel.fromJson(const {
      'id': 'u1',
      'roles': ['SENDER'],
      'kycStatus': 'VERIFIED',
    });

    test('un compte connecté ouvre la session', () {
      expect(
        assistantSignedInAfter(AuthAuthenticated(user), previous: false),
        isTrue,
      );
      expect(
        assistantSignedInAfter(AuthProfileUpdated(user), previous: false),
        isTrue,
      );
    });

    test('initial, invité, compte supprimé, verrouillé : session fermée', () {
      for (final state in <AuthState>[
        const AuthInitial(),
        const AuthGuestSessionReady(),
        const AuthAccountDeleted(),
        const AuthLocked(),
      ]) {
        expect(
          assistantSignedInAfter(state, previous: true),
          isFalse,
          reason: '$state',
        );
      }
    });

    test('chargement ou erreur : l’état précédent est gardé', () {
      for (final state in <AuthState>[
        const AuthLoading(),
        const AuthError(NetworkException('boum')),
      ]) {
        expect(assistantSignedInAfter(state, previous: true), isTrue);
        expect(assistantSignedInAfter(state, previous: false), isFalse);
      }
    });
  });
}
