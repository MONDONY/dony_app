import 'dart:async';

import 'package:dio/dio.dart';

/// Règles communes aux intercepteurs qui rejouent une requête (429, erreurs
/// transitoires, jeton expiré sur 401).
///
/// Une relance passe par [replayRequest] : elle refait toute la chaîne
/// d'intercepteurs (jeton frais, breadcrumb, mapping), sur une COPIE des
/// options marquée d'une profondeur de relance. Le report Sentry final ne part
/// qu'à la profondeur 0 : une tentative intermédiaire n'est jamais rapportée,
/// même quand elle échoue (FLUTTER-J1).
abstract final class RetryPolicy {
  /// En-tête qu'un appelant pose pour autoriser le rejeu d'une écriture : le
  /// back déduplique alors la requête sur cette clé.
  static const idempotencyKeyHeader = 'Idempotency-Key';

  /// Profondeur de relance des options : 0 pour l'appel de l'appelant, n pour
  /// la n-ième requête imbriquée.
  static const depthKey = '_retryDepth';

  /// Compteurs de tentatives posés par chaque intercepteur de relance.
  static const rateLimitAttemptKey = '_retry429Attempt';
  static const transientAttemptKey = '_retryTransientAttempt';
  static const authRefreshedKey = '_authRefreshed';

  static const _safeMethods = {'GET', 'HEAD', 'OPTIONS'};

  /// `true` si la requête peut être rejouée sans risque de doublon côté
  /// serveur : méthode sûre (GET, HEAD, OPTIONS), ou écriture (POST, PUT,
  /// PATCH, DELETE) portant une clé d'idempotence. Un corps multipart ne se
  /// rejoue jamais : Dio refuse un FormData déjà finalisé.
  static bool isReplayable(RequestOptions options) {
    if (options.data is FormData) return false;
    if (_safeMethods.contains(options.method.toUpperCase())) return true;
    return options.headers.entries.any(
      (e) =>
          e.key.toLowerCase() == idempotencyKeyHeader.toLowerCase() &&
          e.value != null &&
          e.value.toString().trim().isNotEmpty,
    );
  }

  static int depthOf(RequestOptions options) =>
      (options.extra[depthKey] as int?) ?? 0;

  /// Nombre de relances déjà faites pour cette requête, tous motifs
  /// confondus. Remonté dans le contexte Sentry (`retry_count`).
  static int retryCountOf(RequestOptions options) =>
      ((options.extra[rateLimitAttemptKey] as int?) ?? 0) +
      ((options.extra[transientAttemptKey] as int?) ?? 0) +
      (options.extra[authRefreshedKey] == true ? 1 : 0);

  /// Rejoue la requête de [err] à travers toute la chaîne de [dio], puis
  /// termine [handler] : résolu avec la réponse, ou passé à l'intercepteur
  /// suivant avec l'erreur finale (déjà convertie en exception métier par la
  /// chaîne imbriquée, compteurs de tentatives compris, profondeur rétablie).
  static Future<void> replayRequest(
    Dio dio,
    DioException err,
    ErrorInterceptorHandler handler, {
    required Map<String, Object?> extra,
  }) async {
    final options = err.requestOptions;
    final depth = depthOf(options);
    final replay = options.copyWith(
      extra: {...options.extra, ...extra, depthKey: depth + 1},
    );
    try {
      handler.resolve(await dio.fetch<dynamic>(replay));
    } on DioException catch (e) {
      final back = e.requestOptions.copyWith(
        extra: {...e.requestOptions.extra, depthKey: depth},
      );
      handler.next(e.copyWith(requestOptions: back));
    }
  }
}

/// Attente entre deux tentatives. Remplaçable en test pour ne pas dormir.
typedef RetrySleep = Future<void> Function(Duration delay);

Future<void> defaultRetrySleep(Duration delay) => Future<void>.delayed(delay);
