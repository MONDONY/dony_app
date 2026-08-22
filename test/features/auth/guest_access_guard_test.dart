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

    test(
      'autorise les routes publiques de recherche, détail et favoris',
      () {
        expect(GuestAccessGuard.isPublicGuestPath('/home'), isTrue);
        expect(
          GuestAccessGuard.isPublicGuestPath('/package-requests/abc/public'),
          isTrue,
        );
        // Les favoris sont le seul contenu qu'un visiteur peut conserver :
        // le backend et le routeur les autorisent déjà à un invité.
        expect(GuestAccessGuard.isPublicGuestPath('/favoris'), isTrue);
        expect(GuestAccessGuard.isPublicGuestPath('/messages'), isFalse);
        expect(GuestAccessGuard.isPublicGuestPath('/profile'), isFalse);
        expect(GuestAccessGuard.isPublicGuestPath('/announcements'), isFalse);
        expect(GuestAccessGuard.isPublicGuestPath('/tracking'), isFalse);
      },
    );
  });
}
