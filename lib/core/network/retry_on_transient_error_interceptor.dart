import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:dony/core/network/retry_policy.dart';

/// Retente automatiquement une requête rejouable ayant échoué pour une cause
/// transitoire (timeout, erreur de connexion, 5xx), avec un backoff
/// exponentiel + jitter, avant de laisser l'erreur remonter à l'appelant.
///
/// Nécessaire pour couvrir le cold-start du backend : au tout premier appel
/// authentifié après relance de l'app (`GET /users/me`), le service peut
/// mettre plusieurs secondes à répondre (JVM/pool de connexions pas encore
/// chauds) — sans retry, l'utilisateur atterrissait sur un écran d'erreur et
/// devait recharger l'app manuellement pour retenter la même requête.
///
/// Limité aux requêtes rejouables ([RetryPolicy.isReplayable]) : GET, HEAD,
/// OPTIONS, ou écriture portant une clé d'idempotence. Un POST, PUT, PATCH ou
/// DELETE sans clé n'est JAMAIS rejoué : un 502 peut arriver après que l'API a
/// traité la requête (paiement, création d'annonce), le rejouer la doublerait.
///
/// Un délai de réception ou d'envoi dépassé n'est rejoué qu'une fois : chaque
/// tentative attend jusqu'à `receiveTimeout` (30 s), trois relances tiendraient
/// l'écran deux minutes.
class RetryOnTransientErrorInterceptor extends Interceptor {
  RetryOnTransientErrorInterceptor(
    this._dio, {
    Random? random,
    RetrySleep? sleep,
  }) : _random = random ?? Random(),
       _sleep = sleep ?? defaultRetrySleep;

  final Dio _dio;
  final Random _random;
  final RetrySleep _sleep;

  static const int maxRetries = 3;
  static const int maxSlowTimeoutRetries = 1;
  static const Duration baseDelay = Duration(milliseconds: 800);
  static const Duration jitterMax = Duration(milliseconds: 400);
  static const _attemptKey = RetryPolicy.transientAttemptKey;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final isSlowTimeout =
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout;
    final isTransient =
        isSlowTimeout ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.connectionError ||
        (statusCode != null && statusCode >= 500);
    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 0;
    // Un appelant qui gère déjà son propre retry avec backoff (ex. le
    // health-check du splash) passe ce flag pour éviter que les deux
    // boucles de retry se cumulent sans le savoir l'une de l'autre.
    final skipRetry = err.requestOptions.extra['skipTransientRetry'] == true;

    final limit = isSlowTimeout ? maxSlowTimeoutRetries : maxRetries;

    if (!RetryPolicy.isReplayable(err.requestOptions) ||
        !isTransient ||
        attempt >= limit ||
        skipRetry) {
      handler.next(err);
      return;
    }

    final delay =
        baseDelay * (1 << attempt) +
        Duration(milliseconds: _random.nextInt(jitterMax.inMilliseconds));
    await _sleep(delay);

    await RetryPolicy.replayRequest(
      _dio,
      err,
      handler,
      extra: {_attemptKey: attempt + 1},
    );
  }
}
