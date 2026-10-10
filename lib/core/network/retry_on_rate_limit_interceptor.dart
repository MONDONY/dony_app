import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:dony/core/network/retry_policy.dart';

/// Retente automatiquement une requête ayant reçu un `429 Too Many Requests`,
/// avec un backoff court et un peu de jitter, avant de laisser l'erreur
/// remonter à l'appelant.
///
/// Nécessaire car le cold-start de l'app tire ~15 requêtes en parallèle
/// (blocs eagerly chargés) : nginx (staging comme prod) peut en jeter
/// quelques-unes en 429 sous cette rafale légitime. Sans retry, ces requêtes
/// échouaient silencieusement pour l'utilisateur — écran vide jusqu'à ce
/// qu'il recharge manuellement l'app, ce qui ne fait que retenter la même
/// rafale un peu plus tard. Le jitter évite que toutes les requêtes 429
/// retentent au même instant et ne reproduisent la rafale initiale.
///
/// Un 429 métier du back (ProblemDetail portant un `code`, comme
/// `code-request-too-soon` ou `recipient-replacement-too-soon`, ou un
/// `retryAfterSeconds`) n'est jamais rejoué : la réponse serait identique
/// quelques centaines de millisecondes plus tard, et l'écran attendait
/// ~1,5 s de relances inutiles avant d'afficher le délai à respecter. Seuls
/// les 429 de limitation (Nginx, corps HTML ou vide) sont relancés.
///
/// Seules les requêtes rejouables le sont ([RetryPolicy.isReplayable]) : GET,
/// HEAD, OPTIONS, ou écriture portant une clé d'idempotence. Un 429 Nginx est
/// rendu avant d'atteindre l'API, un POST y serait donc sans doublon, mais la
/// règle reste la même pour tous les rejeux : aucune écriture sans clé.
class RetryOnRateLimitInterceptor extends Interceptor {
  RetryOnRateLimitInterceptor(this._dio, {Random? random, RetrySleep? sleep})
    : _random = random ?? Random(),
      _sleep = sleep ?? defaultRetrySleep;

  final Dio _dio;
  final Random _random;
  final RetrySleep _sleep;

  static const int maxRetries = 2;
  static const Duration baseDelay = Duration(milliseconds: 400);
  static const Duration jitterMax = Duration(milliseconds: 300);
  static const _attemptKey = RetryPolicy.rateLimitAttemptKey;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 0;

    // Un corps multipart (photo du chat, pièce jointe) ne se rejoue pas
    // (FLUTTER-B4), une écriture sans clé d'idempotence non plus : le 429
    // remonte tel quel à l'appelant.
    if (statusCode != 429 ||
        attempt >= maxRetries ||
        !RetryPolicy.isReplayable(err.requestOptions) ||
        isBusinessRateLimit(err.response?.data)) {
      handler.next(err);
      return;
    }

    final delay =
        baseDelay * (attempt + 1) +
        Duration(milliseconds: _random.nextInt(jitterMax.inMilliseconds));
    await _sleep(delay);

    await RetryPolicy.replayRequest(
      _dio,
      err,
      handler,
      extra: {_attemptKey: attempt + 1},
    );
  }

  /// `true` pour un 429 métier du back : corps problem+json portant un
  /// `code` non vide ou un `retryAfterSeconds`. Un corps texte est décodé
  /// s'il est du JSON ; tout autre corps (HTML Nginx, vide) est générique.
  static bool isBusinessRateLimit(Object? body) {
    Object? data = body;
    if (data is String) {
      final trimmed = data.trim();
      if (!trimmed.startsWith('{')) return false;
      try {
        data = jsonDecode(trimmed);
      } on FormatException {
        return false;
      }
    }
    if (data is! Map) return false;
    final code = data['code'];
    if (code is String && code.trim().isNotEmpty) return true;
    return data.containsKey('retryAfterSeconds');
  }
}
