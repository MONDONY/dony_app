import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

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
class RetryOnRateLimitInterceptor extends Interceptor {
  RetryOnRateLimitInterceptor(this._dio, {Random? random})
    : _random = random ?? Random();

  final Dio _dio;
  final Random _random;

  static const int maxRetries = 2;
  static const Duration baseDelay = Duration(milliseconds: 400);
  static const Duration jitterMax = Duration(milliseconds: 300);
  static const _attemptKey = '_retry429Attempt';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 0;

    if (statusCode != 429 || attempt >= maxRetries) {
      handler.next(err);
      return;
    }

    final delay =
        baseDelay * (attempt + 1) +
        Duration(milliseconds: _random.nextInt(jitterMax.inMilliseconds));
    await Future<void>.delayed(delay);

    final retryOptions = err.requestOptions..extra[_attemptKey] = attempt + 1;
    try {
      final response = await _dio.fetch(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
