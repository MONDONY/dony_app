import 'package:dony/features/home/domain/search_mode.dart';

abstract final class GuestAccessGuard {
  static bool isAllowedShellTab(int index) => index == 0;

  static SearchMode initialSearchMode({required bool isAuthenticated}) =>
      isAuthenticated ? SearchMode.trips : SearchMode.parcels;

  static bool canUseSearchMode(
    SearchMode mode, {
    required bool isAuthenticated,
  }) => isAuthenticated || mode.isParcels;

  static bool isPublicGuestPath(String path) =>
      path == '/home' ||
      path == '/recherche/composer' ||
      path == '/package-requests/search' ||
      RegExp(r'^/package-requests/[^/]+/public$').hasMatch(path);
}
