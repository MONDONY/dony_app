import 'dart:async';

import 'package:dony/core/services/app_log.dart';
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
/// par l'intermédiaire de Firebase — rien à gérer côté application. Le projet
/// Firebase, lui, doit bel et bien porter une clé privée Sign in with Apple :
/// elle vit dans la configuration du fournisseur `apple.com` de la console
/// Firebase (Services ID, Team ID, Key ID, clé `.p8`), jamais dans le dépôt
/// applicatif. Si cette configuration manque côté Firebase, l'appel échoue —
/// en silence pour l'utilisateur, journalisé côté app (cf.
/// [revokeIfAppleUser] et le paramètre `logFailure` du constructeur). Elle
/// exige par ailleurs un `authorizationCode` FRAIS :
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
    void Function(String message, {Map<String, Object>? data})? logFailure,
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
               FirebaseAuth.instance.revokeTokenWithAuthorizationCode(code)),
       _logFailure = logFailure ?? AppLog.warn;

  final List<String> Function() _providerIds;
  final bool Function() _isApplePlatform;
  final Future<String?> Function() _fetchAuthorizationCode;
  final Future<void> Function(String code) _revoke;

  /// Journalise un échec de révocation. Défaut inerte : [AppLog.warn], no-op
  /// tant que `SENTRY_DSN` est absent et documenté comme ne levant jamais.
  /// Injectable pour les tests ; voir la garde dans [revokeIfAppleUser] qui
  /// protège l'appelant même si l'implémentation fournie, elle, lève.
  final void Function(String message, {Map<String, Object>? data}) _logFailure;

  /// Ne fait rien si le compte n'a pas de fournisseur `apple.com`, ou si la
  /// plateforme n'expose pas l'API (Android, web).
  ///
  /// N'échoue jamais : un utilisateur qui a demandé la suppression de son
  /// compte doit l'obtenir même si la révocation Apple tombe. L'appelant
  /// enchaîne donc toujours sur la suppression backend.
  Future<void> revokeIfAppleUser() async {
    try {
      if (!_isApplePlatform()) return;
      if (!_providerIds().contains('apple.com')) return;

      final code = await _fetchAuthorizationCode();
      if (code == null || code.isEmpty) return;
      await _revoke(code);
    } catch (e) {
      // Abandon de la boîte Apple, réseau coupé, API indisponible, clé
      // privée Sign in with Apple absente côté fournisseur Firebase (cf. la
      // doc de tête) : la suppression du compte se poursuit. Ne jamais
      // journaliser le code d'autorisation lui-même, seulement le fait
      // qu'un échec a eu lieu et son type.
      //
      // _isApplePlatform() et _providerIds() sont DANS ce bloc à dessein,
      // pas seulement l'appel réseau final : leur implémentation par défaut
      // lit FirebaseAuth.instance.currentUser, qui peut lever (ex.
      // [core/no-app] si Firebase n'est pas encore initialisé). La garantie
      // « ne bloque jamais la suppression » doit couvrir tout le corps de
      // la méthode, pas seulement son chemin nominal — sinon ce n'est pas
      // une garantie, c'est une coïncidence qui tient tant que ce chemin
      // reste inatteignable.
      try {
        _logFailure(
          'Échec de la révocation du jeton Sign in with Apple',
          data: {'error_type': e.runtimeType.toString()},
        );
      } catch (_) {
        // [_logFailure] est injectable : un journaliseur défaillant ne doit
        // pas, lui non plus, faire échouer la suppression du compte. Cette
        // garde est ce qui rend la garantie vraie même quand l'appelant
        // fournit une implémentation de journalisation qui lève.
      }
    }
  }
}
