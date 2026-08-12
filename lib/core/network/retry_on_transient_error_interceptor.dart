import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

/// Retente automatiquement une requête `GET` ayant échoué pour une cause
/// transitoire (timeout, erreur de connexion, 5xx), avec un backoff
/// exponentiel + jitter, avant de laisser l'erreur remonter à l'appelant.
///
/// Nécessaire pour couvrir le cold-start du backend : au tout premier appel
/// authentifié après relance de l'app (`GET /users/me`), le service peut
/// mettre plusieurs secondes à répondre (JVM/pool de connexions pas encore
/// chauds) — sans retry, l'utilisateur atterrissait sur un écran d'erreur et
/// devait recharger l'app manuellement pour retenter la même requête.
///
/// Limité aux `GET` : ce sont les seules requêtes sûres à rejouer sans
/// risque de doublon côté serveur (paiements, création de ressources, etc.
/// ne sont jamais retentées ici).
class RetryOnTransientErrorInterceptor extends Interceptor {
  RetryOnTransientErrorInterceptor(this._dio, {Random? random})
    : _random = random ?? Random();

  final Dio _dio;
  final Random _random;

  static const int maxRetries = 3;
  static const Duration baseDelay = Duration(milliseconds: 800);
  static const Duration jitterMax = Duration(milliseconds: 400);
  static const _attemptKey = '_retryTransientAttempt';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final method = err.requestOptions.method.toUpperCase();
    final statusCode = err.response?.statusCode;
    final isTransient =
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (statusCode != null && statusCode >= 500);
    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 0;
    // Un appelant qui gère déjà son propre retry avec backoff (ex. le
    // health-check du splash) passe ce flag pour éviter que les deux
    // boucles de retry se cumulent sans le savoir l'une de l'autre.
    final skipRetry = err.requestOptions.extra['skipTransientRetry'] == true;

    if (method != 'GET' || !isTransient || attempt >= maxRetries || skipRetry) {
      handler.next(err);
      return;
    }

    final delay =
        baseDelay * (1 << attempt) +
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
