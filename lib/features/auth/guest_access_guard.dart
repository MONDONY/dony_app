import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';

abstract final class GuestAccessGuard {
  static bool isAllowedShellTab(int index) => index == 0;

  /// Favoris inclus : c'est le seul contenu qu'un visiteur peut conserver, et
  /// le backend autorise déjà un invité sur `GET/PUT/DELETE /favorites/*`.
  static bool isPublicGuestPath(String path) =>
      path == '/home' ||
      path == '/recherche/composer' ||
      path == '/package-requests/search' ||
      path == '/favoris' ||
      RegExp(r'^/package-requests/[^/]+/public$').hasMatch(path);

  /// Un visiteur qui rouvre l'app avec une session anonyme déjà ouverte n'a
  /// jamais son `AuthBloc` qui bouge : `AuthCheckRequested` ne part que pour
  /// `hasRealSession` (`GET /auth/me` répondrait 404 pour un invité), donc
  /// `AuthBloc` reste en `AuthInitial` sans aucune transition — rien d'autre
  /// dans l'app ne recharge alors ses favoris déjà posés.
  ///
  /// Un compte réel n'a pas besoin de ce chemin : `AuthCheckRequested` →
  /// `AuthAuthenticated` recharge déjà les favoris (cf. `app.dart`).
  ///
  /// Sans session du tout (`hasSession` faux), il n'y a aucun jeton Firebase
  /// à présenter : l'appel `/favorites/ids` échouerait sans authentification
  /// — ne jamais le déclencher dans ce cas. D'où le test à trois branches
  /// (compte réel / anonyme / aucune session), et pas un simple `!hasRealSession`.
  static bool shouldLoadGuestFavorites(FirebaseSessionProbe probe) =>
      probe.hasSession && !probe.hasRealSession;

  /// Une session anonyme vient tout juste de s'ouvrir (CTA « Parcourir sans
  /// compte ») : c'est le seul état qui doit déclencher un rechargement
  /// immédiat des favoris depuis le `BlocListener<AuthBloc>` de `app.dart`.
  /// `AuthAuthenticated` a déjà son propre chemin (`FavoritesMigration`),
  /// tout le reste ne doit rien déclencher ici.
  static bool isFreshGuestSession(AuthState state) =>
      state is AuthGuestSessionReady;
}
