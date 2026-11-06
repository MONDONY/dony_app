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

    test('onboardingSeenAt posé : consentement, puis accueil', () {
      expect(
        resolvePostSignupRoute(_user(onboardingSeenAt: DateTime(2026, 10, 2))),
        '/auth/analytics-consent?next=home',
      );
    });

    test('utilisateur inconnu : écran « Une dernière chose »', () {
      expect(resolvePostSignupRoute(null), analyticsConsentRoute);
    });
  });

  group('resolvePostLoginRoute', () {
    test('compte existant : la question passe d\'abord, puis l\'accueil', () {
      expect(resolvePostLoginRoute(), '/auth/analytics-consent?next=home');
    });
  });

  group('resolvePostSocialLoginRoute', () {
    test('Google ou Apple, compte existant : la question, puis le verrou', () {
      expect(
        resolvePostSocialLoginRoute(),
        '/auth/analytics-consent?next=local',
      );
    });
  });

  group('analyticsConsentDestination', () {
    test('next=local : verrou local', () {
      expect(analyticsConsentDestination('local'), '/auth/local');
    });

    test('sans paramètre : « Faisons connaissance » (nouveau compte)', () {
      expect(analyticsConsentDestination(null), '/auth/profile-basics');
    });

    test('next=home : accueil', () {
      expect(analyticsConsentDestination('home'), '/home');
    });

    test('toute autre valeur retombe sur « Faisons connaissance »', () {
      expect(
        analyticsConsentDestination('/trips/create'),
        '/auth/profile-basics',
      );
      expect(
        analyticsConsentDestination('https://exemple.test'),
        '/auth/profile-basics',
      );
    });
  });
}
