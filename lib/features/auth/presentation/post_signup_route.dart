import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/presentation/screens/analytics_consent_screen.dart';

/// Route à suivre juste après la création du compte.
///
/// L'inscription se réduit au code : un nouveau compte passe ensuite par la
/// question de la mesure d'usage (`analyticsConsentRoute`, qui passe son
/// chemin quand elle est inutile), puis par « Faisons connaissance » (nom et
/// pays facultatifs), qui mène aux premiers pas. Un compte qui a déjà vu la
/// fin de l'inscription (`onboarding_seen_at`, posé à l'affichage des premiers
/// pas : réinstallation, second appareil) va droit à l'accueil, où la feuille
/// de consentement reste le filet pour qui n'a pas encore répondu.
///
/// Fonction pure et synchrone : ni réseau, ni analytics.
String resolvePostSignupRoute(UserModel? user) =>
    user?.onboardingSeenAt != null ? '/home' : analyticsConsentRoute;
