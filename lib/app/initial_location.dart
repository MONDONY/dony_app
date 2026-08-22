import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Calcule la route d'entrée de l'application **uniquement à partir de l'état
/// local** (session Firebase persistée, code local, onboarding déjà vu).
///
/// Aucun appel réseau ici : la disponibilité du backend n'est pas un prérequis
/// pour savoir où envoyer l'utilisateur. Le profil serveur est chargé en
/// arrière-plan (`AuthCheckRequested`, cf. `app.dart`) et chaque écran gère son
/// propre état de chargement/erreur. C'est ce qui permet de n'avoir qu'un seul
/// splash (le natif) au lieu d'un second écran bloquant sur un health check.
Future<String> resolveInitialLocation({
  FirebaseAuth? firebaseAuth,
  LocalAuthService? localAuthService,
  HiveService? hiveService,
}) async {
  final session = FirebaseSessionProbe(auth: firebaseAuth);
  final prefs = (hiveService ?? getIt<HiveService>()).userPrefs;
  final onboardingDone =
      prefs.get('onboarding_done', defaultValue: false) as bool;

  // `hasRealSession`, et non « une session existe » : un visiteur porte une
  // session anonyme dès son premier « Parcourir sans compte », et cette
  // session survit aux relances. La tester par simple nullité ferait sauter
  // l'onboarding à quiconque a un jour appuyé sur ce bouton, et enverrait sur
  // /home un appareil sans aucun compte.
  if (!session.hasRealSession) {
    return onboardingDone ? '/auth/method' : '/onboarding';
  }

  // Session Firebase restaurée : on n'exige jamais un nouvel OTP. Le code local
  // suffit à déverrouiller, et il reste facultatif.
  final pinSet = await (localAuthService ?? getIt<LocalAuthService>())
      .isPinSet();
  return pinSet ? '/auth/local' : '/home';
}
