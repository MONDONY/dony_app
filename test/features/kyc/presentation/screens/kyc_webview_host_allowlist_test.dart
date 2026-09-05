import 'package:dony/features/kyc/presentation/screens/kyc_webview_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// La webview de vérification n'ouvre que les pages d'un fournisseur connu.
///
/// C'est le seul rempart entre l'utilisateur, qui va y présenter sa pièce
/// d'identité et son visage, et une page qui se ferait passer pour le
/// fournisseur. La liste était codée en dur sur Stripe : la page Didit restait
/// blanche puis la webview se refermait, sans message, ce qui rendait le
/// parcours entier inutilisable et le diagnostic difficile (constaté sur
/// appareil réel le 2026-09-05).
void main() {
  group('hôtes acceptés', () {
    test('Didit', () {
      expect(isVerificationProviderHost('verify.didit.me'), isTrue);
      expect(isVerificationProviderHost('didit.me'), isTrue);
    });

    test('Stripe, tant que des sessions historiques peuvent se rouvrir', () {
      expect(isVerificationProviderHost('verify.stripe.com'), isTrue);
      expect(isVerificationProviderHost('stripe.com'), isTrue);
    });
  });

  group('hôtes refusés', () {
    test('un domaine qui imite le fournisseur en suffixe', () {
      expect(isVerificationProviderHost('verify.didit.me.attaquant.com'), isFalse);
      expect(isVerificationProviderHost('verify.stripe.com.attaquant.com'), isFalse);
    });

    test('un domaine qui contient le nom sans en être un sous-domaine', () {
      expect(isVerificationProviderHost('didit.me.evil.io'), isFalse);
      expect(isVerificationProviderHost('notdidit.me'), isFalse);
      expect(isVerificationProviderHost('faux-stripe.com'), isFalse);
    });

    test('un tiers quelconque', () {
      expect(isVerificationProviderHost('yadony.com'), isFalse);
      expect(isVerificationProviderHost('example.com'), isFalse);
      expect(isVerificationProviderHost(''), isFalse);
    });
  });
}
