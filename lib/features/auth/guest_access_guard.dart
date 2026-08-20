abstract final class GuestAccessGuard {
  static bool isAllowedShellTab(int index) => index == 0;

  static bool isPublicGuestPath(String path) =>
      path == '/home' ||
      path == '/recherche/composer' ||
      path == '/package-requests/search' ||
      RegExp(r'^/package-requests/[^/]+/public$').hasMatch(path);
}
