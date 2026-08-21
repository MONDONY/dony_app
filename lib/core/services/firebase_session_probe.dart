import 'package:firebase_auth/firebase_auth.dart';

/// Indirection testable autour de `FirebaseAuth.instance.currentUser`.
///
/// Synchrone et disponible immédiatement après un cold start (session
/// persistée par le SDK Firebase), contrairement à `AuthBloc.state`, qui
/// attend la réponse réseau de `GET /auth/me` — un écran qui décide de son
/// affichage initial (onglet, mode) sur `AuthBloc.state.currentUser` peut
/// donc voir un utilisateur pourtant connecté comme invité pendant cette
/// fenêtre. `router.dart` s'appuie déjà sur la même source pour ses
/// redirections d'auth ; passer par GetIt (plutôt que l'appel statique
/// direct) permet aux écrans qui en dépendent de rester testables sans
/// initialiser Firebase dans les widget tests.
class FirebaseSessionProbe {
  const FirebaseSessionProbe();

  bool get hasSession => FirebaseAuth.instance.currentUser != null;
}
