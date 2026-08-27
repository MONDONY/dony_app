import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Révoque le jeton Sign in with Apple au moment où l'utilisateur supprime
/// son compte.
///
/// Apple l'exige depuis 2022 pour toute application proposant Sign in with
/// Apple : révoquer les jetons Firebase ne suffit pas, l'autorisation reste
/// active côté Apple et le compte réapparaît dans les réglages iOS.
///
/// `FirebaseAuth.revokeTokenWithAuthorizationCode` fait l'appel à l'API Apple
/// par l'intermédiaire de Firebase — pas de clé `.p8` à gérer, pas de
/// changement backend. Elle exige en revanche un `authorizationCode` FRAIS :
/// celui obtenu à la connexion est à usage unique et expire en cinq minutes.
/// D'où la ré-authentification Apple juste avant. Elle est de toute façon
/// souhaitable devant une action irréversible.
///
/// Les dépendances passent par le constructeur pour rester testables sans
/// Firebase ni boîte de dialogue système.
class AppleTokenRevoker {
  AppleTokenRevoker({
    List<String> Function()? providerIds,
    bool Function()? isApplePlatform,
    Future<String?> Function()? fetchAuthorizationCode,
    Future<void> Function(String code)? revoke,
  }) : _providerIds =
           providerIds ??
           (() =>
               FirebaseAuth.instance.currentUser?.providerData
                   .map((p) => p.providerId)
                   .toList() ??
               const []),
       _isApplePlatform =
           isApplePlatform ??
           (() =>
               defaultTargetPlatform == TargetPlatform.iOS ||
               defaultTargetPlatform == TargetPlatform.macOS),
       _fetchAuthorizationCode =
           fetchAuthorizationCode ??
           (() async {
             final credential = await SignInWithApple.getAppleIDCredential(
               scopes: const [AppleIDAuthorizationScopes.email],
             );
             return credential.authorizationCode;
           }),
       _revoke =
           revoke ??
           ((code) =>
               FirebaseAuth.instance.revokeTokenWithAuthorizationCode(code));

  final List<String> Function() _providerIds;
  final bool Function() _isApplePlatform;
  final Future<String?> Function() _fetchAuthorizationCode;
  final Future<void> Function(String code) _revoke;

  /// Ne fait rien si le compte n'a pas de fournisseur `apple.com`, ou si la
  /// plateforme n'expose pas l'API (Android, web).
  ///
  /// N'échoue jamais : un utilisateur qui a demandé la suppression de son
  /// compte doit l'obtenir même si la révocation Apple tombe. L'appelant
  /// enchaîne donc toujours sur la suppression backend.
  Future<void> revokeIfAppleUser() async {
    if (!_isApplePlatform()) return;
    if (!_providerIds().contains('apple.com')) return;

    try {
      final code = await _fetchAuthorizationCode();
      if (code == null || code.isEmpty) return;
      await _revoke(code);
    } catch (_) {
      // Abandon de la boîte Apple, réseau coupé, API indisponible : la
      // suppression du compte se poursuit. Ne pas journaliser le code.
    }
  }
}
