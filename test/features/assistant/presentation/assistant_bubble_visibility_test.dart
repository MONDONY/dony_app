import 'package:dony/features/assistant/presentation/assistant_bubble_visibility.dart';
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
    ]) {
      expect(isAssistantBubbleExcludedLocation(p), isFalse, reason: p);
    }
  });

  test('conditions', () {
    bool show({
      bool signedIn = true,
      bool enabled = true,
      bool disabled = false,
      bool keyboardOpen = false,
      String path = '/home',
    }) => shouldShowAssistantBubble(
      path: path,
      signedIn: signedIn,
      enabled: enabled,
      disabled: disabled,
      keyboardOpen: keyboardOpen,
    );
    expect(show(), isTrue);
    expect(show(signedIn: false), isFalse);
    expect(show(enabled: false), isFalse);
    expect(show(disabled: true), isFalse);
    expect(show(keyboardOpen: true), isFalse);
    expect(show(path: '/assistant'), isFalse);
    expect(show(path: '/auth/local'), isFalse);
  });
}
