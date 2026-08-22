import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/guest_access_guard.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stub minimal du probe : seuls `hasSession`/`hasRealSession` pilotent
/// `shouldLoadGuestFavorites`, `isAnonymous` n'est jamais lu par le garde
/// mais reste requis par l'interface.
class _StubProbe implements FirebaseSessionProbe {
  const _StubProbe({required this.hasSession, required this.hasRealSession});

  @override
  final bool hasSession;
  @override
  final bool hasRealSession;
  @override
  bool get isAnonymous => hasSession && !hasRealSession;
}

UserModel _makeUser() => const UserModel(
  id: 'uid-1',
  roles: ['ROLE_SENDER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

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

    group('shouldLoadGuestFavorites', () {
      test(
        'compte réel → false (AuthCheckRequested recharge déjà les favoris)',
        () {
          expect(
            GuestAccessGuard.shouldLoadGuestFavorites(
              const _StubProbe(hasSession: true, hasRealSession: true),
            ),
            isFalse,
          );
        },
      );

      test('session anonyme → true (rien d\'autre ne les recharge)', () {
        expect(
          GuestAccessGuard.shouldLoadGuestFavorites(
            const _StubProbe(hasSession: true, hasRealSession: false),
          ),
          isTrue,
        );
      });

      test(
        'aucune session → false (aucun jeton à présenter à /favorites)',
        () {
          expect(
            GuestAccessGuard.shouldLoadGuestFavorites(
              const _StubProbe(hasSession: false, hasRealSession: false),
            ),
            isFalse,
          );
        },
      );
    });

    group('isFreshGuestSession', () {
      test('AuthGuestSessionReady → true', () {
        expect(
          GuestAccessGuard.isFreshGuestSession(const AuthGuestSessionReady()),
          isTrue,
        );
      });

      test('tout autre état → false', () {
        expect(
          GuestAccessGuard.isFreshGuestSession(const AuthInitial()),
          isFalse,
        );
        expect(
          GuestAccessGuard.isFreshGuestSession(const AuthLoading()),
          isFalse,
        );
        expect(
          GuestAccessGuard.isFreshGuestSession(AuthAuthenticated(_makeUser())),
          isFalse,
        );
      });
    });
  });
}
