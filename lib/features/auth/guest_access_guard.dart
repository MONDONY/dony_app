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
}
