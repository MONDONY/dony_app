import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/presentation/post_signup_route.dart';
import 'package:dony/features/auth/presentation/screens/analytics_consent_screen.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _user({DateTime? onboardingSeenAt}) => UserModel(
  id: 'u1',
  roles: const [],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
  onboardingSeenAt: onboardingSeenAt,
);

/// `resolvePostSignupRoute` : après le code, un nouveau compte passe par la
/// question de la mesure d'usage (puis « Faisons connaissance »), sauf s'il a
/// déjà vu la fin de l'inscription (réinstallation, second appareil).
void main() {
  group('resolvePostSignupRoute', () {
    test('onboardingSeenAt nul : écran « Une dernière chose »', () {
      expect(resolvePostSignupRoute(_user()), analyticsConsentRoute);
      expect(analyticsConsentRoute, '/auth/analytics-consent');
    });

    test('onboardingSeenAt posé : accueil', () {
      expect(
        resolvePostSignupRoute(_user(onboardingSeenAt: DateTime(2026, 10, 2))),
        '/home',
      );
    });

    test('utilisateur inconnu : écran « Une dernière chose »', () {
      expect(resolvePostSignupRoute(null), analyticsConsentRoute);
    });
  });
}
