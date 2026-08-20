import 'package:dony/features/auth/guest_access_guard.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GuestAccessGuard', () {
    test('autorise uniquement l’onglet recherche pour un invité', () {
      expect(GuestAccessGuard.isAllowedShellTab(0), isTrue);
      expect(GuestAccessGuard.isAllowedShellTab(1), isFalse);
      expect(GuestAccessGuard.isAllowedShellTab(2), isFalse);
      expect(GuestAccessGuard.isAllowedShellTab(3), isFalse);
      expect(GuestAccessGuard.isAllowedShellTab(4), isFalse);
    });

    test('autorise seulement les routes publiques de recherche et détail', () {
      expect(GuestAccessGuard.isPublicGuestPath('/home'), isTrue);
      expect(
        GuestAccessGuard.isPublicGuestPath('/package-requests/abc/public'),
        isTrue,
      );
      expect(GuestAccessGuard.isPublicGuestPath('/favoris'), isFalse);
      expect(GuestAccessGuard.isPublicGuestPath('/messages'), isFalse);
      expect(GuestAccessGuard.isPublicGuestPath('/profile'), isFalse);
      expect(GuestAccessGuard.isPublicGuestPath('/announcements'), isFalse);
      expect(GuestAccessGuard.isPublicGuestPath('/tracking'), isFalse);
    });

    test('démarre les invités sur la recherche colis publique', () {
      expect(
        GuestAccessGuard.initialSearchMode(isAuthenticated: false),
        SearchMode.parcels,
      );
      expect(
        GuestAccessGuard.initialSearchMode(isAuthenticated: true),
        SearchMode.trips,
      );
    });

    test('bloque la recherche trajets pour un invité', () {
      expect(
        GuestAccessGuard.canUseSearchMode(
          SearchMode.parcels,
          isAuthenticated: false,
        ),
        isTrue,
      );
      expect(
        GuestAccessGuard.canUseSearchMode(
          SearchMode.trips,
          isAuthenticated: false,
        ),
        isFalse,
      );
      expect(
        GuestAccessGuard.canUseSearchMode(
          SearchMode.trips,
          isAuthenticated: true,
        ),
        isTrue,
      );
    });
  });
}
