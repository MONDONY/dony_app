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
///
/// Source unique du statut invité dans l'application. Le statut vient du SDK
/// Firebase, jamais d'un état applicatif : après l'inscription, l'utilisateur
/// change d'UID et de provider, et ce probe suit automatiquement.
///
/// Ne pas confondre avec `AuthBloc.state.currentUser`, qui répond à une autre
/// question : « ai-je un compte côté serveur ? ». Un invité peut avoir une
/// session Firebase (anonyme) sans aucun compte serveur.
class FirebaseSessionProbe {
  const FirebaseSessionProbe({FirebaseAuth? auth}) : _auth = auth;

  final FirebaseAuth? _auth;

  FirebaseAuth get _instance => _auth ?? FirebaseAuth.instance;

  /// Une session Firebase existe, anonyme comprise.
  bool get hasSession => _instance.currentUser != null;

  /// La session courante est anonyme.
  bool get isAnonymous => _instance.currentUser?.isAnonymous ?? false;

  /// Une session existe et appartient à un utilisateur réel.
  ///
  /// C'est ce prédicat qui remplace les anciens `currentUser != null` dont
  /// l'intention était « un vrai utilisateur est connecté ».
  bool get hasRealSession {
    final user = _instance.currentUser;
    return user != null && !user.isAnonymous;
  }
}
