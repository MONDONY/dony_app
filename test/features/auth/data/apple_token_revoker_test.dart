import 'package:dony/features/auth/data/apple_token_revoker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppleTokenRevoker', () {
    test('ne fait rien si aucun fournisseur apple.com', () async {
      var askedForCode = false;
      final revoker = AppleTokenRevoker(
        providerIds: () => ['phone', 'google.com'],
        isApplePlatform: () => true,
        fetchAuthorizationCode: () async {
          askedForCode = true;
          return 'code';
        },
        revoke: (_) async {},
      );

      await revoker.revokeIfAppleUser();

      expect(askedForCode, isFalse);
    });

    test('ne fait rien hors plateforme Apple', () async {
      var askedForCode = false;
      final revoker = AppleTokenRevoker(
        providerIds: () => ['apple.com'],
        isApplePlatform: () => false,
        fetchAuthorizationCode: () async {
          askedForCode = true;
          return 'code';
        },
        revoke: (_) async {},
      );

      await revoker.revokeIfAppleUser();

      expect(askedForCode, isFalse);
    });

    test('révoque avec un code frais si le compte est Apple', () async {
      String? revokedWith;
      final revoker = AppleTokenRevoker(
        providerIds: () => ['apple.com'],
        isApplePlatform: () => true,
        fetchAuthorizationCode: () async => 'code-frais',
        revoke: (code) async => revokedWith = code,
      );

      await revoker.revokeIfAppleUser();

      expect(revokedWith, 'code-frais');
    });

    test('un échec de révocation ne remonte jamais', () async {
      final revoker = AppleTokenRevoker(
        providerIds: () => ['apple.com'],
        isApplePlatform: () => true,
        fetchAuthorizationCode: () async => 'code',
        revoke: (_) async => throw Exception('réseau coupé'),
      );

      await expectLater(revoker.revokeIfAppleUser(), completes);
    });

    test('un abandon de la boîte Apple ne remonte jamais', () async {
      var revokeCalled = false;
      final revoker = AppleTokenRevoker(
        providerIds: () => ['apple.com'],
        isApplePlatform: () => true,
        fetchAuthorizationCode: () async => throw Exception('annulé'),
        revoke: (_) async => revokeCalled = true,
      );

      await expectLater(revoker.revokeIfAppleUser(), completes);
      expect(revokeCalled, isFalse);
    });

    test('un providerIds() qui lève ne remonte jamais', () async {
      // Verrouille la garde : _isApplePlatform()/_providerIds() doivent
      // rester DANS le try. Leur implémentation par défaut lit
      // FirebaseAuth.instance.currentUser, qui peut lever ([core/no-app]
      // si Firebase n'est pas initialisé) avant même d'atteindre l'appel
      // réseau. Si ces lectures ressortaient du bloc protégé, cette
      // exception traverserait revokeIfAppleUser() et ferait échouer la
      // suppression chez l'appelant — exactement ce que cette méthode ne
      // doit jamais permettre.
      var fetchCalled = false;
      final revoker = AppleTokenRevoker(
        providerIds: () => throw Exception('FirebaseAuth non initialisé'),
        isApplePlatform: () => true,
        fetchAuthorizationCode: () async {
          fetchCalled = true;
          return 'code';
        },
        revoke: (_) async {},
      );

      await expectLater(revoker.revokeIfAppleUser(), completes);
      expect(fetchCalled, isFalse);
    });

    test(
      'journalise l\'échec sans jamais y inclure le code d\'autorisation',
      () async {
        String? loggedMessage;
        Map<String, Object>? loggedData;
        final revoker = AppleTokenRevoker(
          providerIds: () => ['apple.com'],
          isApplePlatform: () => true,
          fetchAuthorizationCode: () async => 'code-secret-jamais-loggue',
          revoke: (_) async => throw Exception('réseau coupé'),
          logFailure: (message, {data}) {
            loggedMessage = message;
            loggedData = data;
          },
        );

        await revoker.revokeIfAppleUser();

        expect(loggedMessage, isNotNull);
        expect(loggedData, isNotNull);
        expect(
          '$loggedMessage${loggedData ?? ''}',
          isNot(contains('code-secret-jamais-loggue')),
        );
      },
    );

    test(
      'journalise le code Firebase sans jamais y inclure le message brut',
      () async {
        // Verrouille le correctif : sans le code (ex. requires-recent-login,
        // operation-not-allowed si le fournisseur apple.com est mal
        // configuré côté Firebase), error_type dit seulement « une
        // FirebaseAuthException », ce qui ne permet pas de diagnostiquer une
        // panne de configuration. Le message brut, lui, ne doit jamais fuiter
        // : il pourrait contenir le code d'autorisation Apple.
        Map<String, Object>? loggedData;
        final revoker = AppleTokenRevoker(
          providerIds: () => ['apple.com'],
          isApplePlatform: () => true,
          fetchAuthorizationCode: () async => 'code-secret-jamais-loggue',
          revoke: (_) async => throw FirebaseAuthException(
            code: 'internal-error',
            message: 'message-brut-jamais-loggue',
          ),
          logFailure: (message, {data}) => loggedData = data,
        );

        await revoker.revokeIfAppleUser();

        expect(loggedData?['firebase_error_code'], 'internal-error');
        expect(
          loggedData.toString(),
          isNot(contains('message-brut-jamais-loggue')),
        );
      },
    );

    test('un journaliseur qui lève ne bloque jamais la suppression', () async {
      // Verrouille la garde du bloc catch interne : _logFailure est
      // injectable, donc une implémentation défaillante (fournie par un
      // appelant, ou en test) ne doit pas non plus faire remonter
      // d'exception depuis revokeIfAppleUser(). Le contrat « ne bloque
      // jamais la suppression » doit survivre même à un journaliseur cassé.
      final revoker = AppleTokenRevoker(
        providerIds: () => ['apple.com'],
        isApplePlatform: () => true,
        fetchAuthorizationCode: () async => 'code',
        revoke: (_) async => throw Exception('réseau coupé'),
        logFailure: (message, {data}) => throw Exception('journaliseur cassé'),
      );

      await expectLater(revoker.revokeIfAppleUser(), completes);
    });
  });
}
