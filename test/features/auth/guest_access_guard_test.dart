import 'package:dony/features/auth/guest_access_guard.dart';
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
  });
}
