import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/presentation/screens/profile_basics_screen.dart';

/// Route à suivre juste après la création du compte.
///
/// L'inscription se réduit au code : un nouveau compte passe ensuite par
/// « Faisons connaissance » (nom et pays facultatifs), qui mène aux premiers
/// pas. Un compte qui a déjà vu la fin de l'inscription (`onboarding_seen_at`,
/// posé à l'affichage des premiers pas : réinstallation, second appareil) va
/// droit à l'accueil.
///
/// Fonction pure et synchrone : ni réseau, ni analytics. Le consentement
/// analytics est demandé à part, en feuille sur l'accueil.
String resolvePostSignupRoute(UserModel? user) =>
    user?.onboardingSeenAt != null ? '/home' : profileBasicsRoute;
