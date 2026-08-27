import 'package:dony/features/auth/data/apple_token_revoker.dart';
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
  });
}
