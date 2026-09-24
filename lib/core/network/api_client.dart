import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/metrics_interceptor.dart';
import 'package:dony/core/network/offline_fast_fail_interceptor.dart';
import 'package:dony/core/network/retry_on_rate_limit_interceptor.dart';
import 'package:dony/core/network/retry_on_transient_error_interceptor.dart';
import 'package:dony/core/network/tls_pinned_ca.dart';
import 'package:dony/core/services/device_id_service.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// Épinglage TLS de l'API de production.
//
// Le certificat épinglé vit dans `tls_pinned_ca.dart` plutôt que dans un
// `--dart-define` : passer un PEM entier par la ligne de commande faisait
// échouer la chaîne iOS (« File name too long »), et le remplacer par une
// empreinte avait introduit un défaut pire encore (voir plus bas).
//
// Activé au build via --dart-define-from-file=env.prod.json :
//   "TLS_PINNING": "on"
// Absent ou vide en dev et en staging, qui servent un autre certificat.
// Toujours désactivé en debug, pour laisser passer Charles ou mitmproxy.
const _tlsPinning = String.fromEnvironment('TLS_PINNING');

class ApiClient {
  ApiClient({
    required String baseUrl,
    required DeviceIdService deviceIdService,
    ErrorReportingService? errorReporter,
  }) : _errorReporter = errorReporter {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _configureCertificatePinning();
    // Ajouté en tout premier : voir OfflineFastFailInterceptor.
    _dio.interceptors.add(OfflineFastFailInterceptor(Connectivity()));
    _dio.interceptors.add(_AuthInterceptor(deviceIdService));

    // Piste HTTP dans Sentry (breadcrumbs) — active en tout mode, mais no-op
    // tant que SENTRY_DSN est absent. On ne pousse QUE méthode + chemin + statut :
    // jamais les corps ni les en-têtes (tokens Firebase, secrets Stripe, KYC).
    _dio.interceptors.add(_SentryBreadcrumbInterceptor());

    if (kDebugMode) {
      // Log only method/path/status. Bodies and headers contain Firebase
      // ID tokens, Stripe client secrets, FCM tokens and KYC data — never
      // dump them to logcat / Xcode console.
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint('[HTTP] → ${options.method} ${options.uri.path}');
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint(
              '[HTTP] ← ${response.statusCode} ${response.requestOptions.uri.path}',
            );
            handler.next(response);
          },
          onError: (err, handler) {
            debugPrint(
              '[HTTP] ✗ ${err.response?.statusCode ?? 'no-response'} '
              '${err.requestOptions.uri.path}',
            );
            handler.next(err);
          },
        ),
      );
    }

    if (kProfileMode || kDebugMode) {
      _dio.interceptors.add(
        MetricsInterceptor(MetricsInterceptor.globalCollector),
      );
    }

    // dio 5 enchaîne les onError dans l'ORDRE D'AJOUT (dio_mixin.dart : « execute
    // in FIFO order »), pas à l'envers. _AuthInterceptor, ajouté en premier,
    // convertit donc l'erreur avant tout le monde ; les retries ci-dessous s'en
    // accommodent parce que la conversion conserve `response` et `type`, qu'ils
    // relisent (statusCode 429, timeouts, 5xx).
    _dio.interceptors.add(RetryOnRateLimitInterceptor(_dio));
    _dio.interceptors.add(RetryOnTransientErrorInterceptor(_dio));

    // Ajouté EN DERNIER : ne voit que l'échec final. Placé avant les retries, il
    // rapportait chaque tentative intermédiaire, y compris celles qu'un retry
    // finissait par résoudre (une requête retentée trois fois puis réussie
    // produisait trois événements Sentry).
    final errorReporter = _errorReporter;
    if (errorReporter != null) {
      _dio.interceptors.add(_SentryErrorReportingInterceptor(errorReporter));
    }
  }

  late final Dio _dio;
  final ErrorReportingService? _errorReporter;

  Dio get dio => _dio;

  // Rejects any connection to a server whose certificate doesn't match the
  // pinned SHA-256 fingerprint — even if that certificate is signed by a
  // trusted CA (MITM protection). SecurityContext(withTrustedRoots: false)
  // means the platform's normal CA trust check never short-circuits this:
  // badCertificateCallback fires for every connection, not just untrusted
  // ones, so the fingerprint comparison below is the only thing deciding
  // trust.
  //
  // Pinning is intentionally skipped when:
  //   • running in debug mode (allows Charles/mitmproxy during dev)
  //   • _tlsCertPinSha256 is empty (env.dev.json / env.staging.json default —
  //     staging serves a different certificate, no pin configured there)
  //   • running on web (dart:io not available)
  void _configureCertificatePinning() {
    if (kIsWeb || kDebugMode || _tlsPinning != 'on') return;
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      // On ne compare pas une empreinte dans `badCertificateCallback` : ce
      // rappel reçoit le certificat au niveau duquel la validation a échoué,
      // c'est-à-dire le sommet de la chaîne présentée (mesuré : `ISRG Root
      // X2`), et jamais celui du serveur. Une empreinte de feuille n'y
      // correspond donc jamais, et tous les appels étaient refusés.
      //
      // À la place, l'intermédiaire émetteur devient la seule ancre de
      // confiance : la chaîne du serveur ne valide que si elle remonte à lui.
      // Les racines du système sont écartées, sinon n'importe quelle autorité
      // reconnue suffirait et il n'y aurait plus d'épinglage du tout.
      return HttpClient(
        // `false` est le défaut de Dart, mais on l'écrit : c'est lui qui
        // exclut les racines du système, et donc tout l'épinglage.
        // ignore: avoid_redundant_argument_values
        context: SecurityContext(withTrustedRoots: false)
          ..setTrustedCertificatesBytes(
            const Utf8Encoder().convert(tlsPinnedIssuerPem),
          ),
      );
    };
  }
}

class _SentryErrorReportingInterceptor extends Interceptor {
  const _SentryErrorReportingInterceptor(this._reporter);

  final ErrorReportingService _reporter;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    unawaited(
      _reporter.report(
        err,
        operation: 'http.${err.requestOptions.method.toUpperCase()}',
        stackTrace: err.stackTrace,
        statusCode: err.response?.statusCode,
        context: {
          'method': err.requestOptions.method.toUpperCase(),
          'endpoint': err.requestOptions.uri.path,
          'feature': _featureForPath(err.requestOptions.uri.path),
        },
      ),
    );
    handler.next(err);
  }

  static String _featureForPath(String path) {
    for (final feature in const [
      'payments',
      'kyc',
      'tracking',
      'notifications',
      'auth',
    ]) {
      if (path.contains('/$feature')) return feature;
    }
    return 'network';
  }
}

/// Émet un breadcrumb Sentry par réponse/erreur HTTP. PII-free : uniquement
/// méthode, chemin (sans query string) et code de statut. Ces miettes forment
/// la piste réseau attachée au prochain incident capturé.
class _SentryBreadcrumbInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _crumb(response.requestOptions, response.statusCode, SentryLevel.info);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    _crumb(
      err.requestOptions,
      status,
      (status != null && status < 500)
          ? SentryLevel.warning
          : SentryLevel.error,
    );
    handler.next(err);
  }

  void _crumb(RequestOptions options, int? status, SentryLevel level) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        category: 'http',
        type: 'http',
        level: level,
        data: {
          'method': options.method,
          'path': options.uri.path,
          'status_code': ?status,
        },
      ),
    );
  }
}

class _AuthInterceptor extends Interceptor {
  final DeviceIdService _deviceIdService;
  _AuthInterceptor(this._deviceIdService);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final isCritical =
            options.path.contains('/payments') ||
            options.path.contains('/kyc') ||
            options.path.contains('/tracking/events') ||
            options.path.contains('/bids/checkout');
        final token = await user.getIdToken(isCritical);
        options.headers['Authorization'] = 'Bearer $token';
        final deviceId = await _deviceIdService.getDeviceId();
        options.headers['X-Device-Id'] = deviceId;
      }
    } on FirebaseException catch (e) {
      if (e.code == 'no-app') {
        // Firebase genuinely not initialized yet — proceed unauthenticated.
        handler.next(options);
        return;
      }
      // Any other Firebase error should NOT silently proceed. Le rejet porte une
      // AppException typée : avec une simple String, unwrapDioError tombait sur
      // « Erreur réseau » et la file hors-ligne rejouait l'appel à l'infini
      // comme une panne de connexion.
      handler.reject(
        DioException(
          requestOptions: options,
          error: const UnauthorizedException(
            'Authentification impossible',
            'auth-token-unavailable',
          ),
        ),
      );
      return;
    } catch (e) {
      // Unexpected error — reject instead of silently proceeding.
      handler.reject(
        DioException(
          requestOptions: options,
          error: const UnauthorizedException(
            'Authentification impossible',
            'auth-token-unavailable',
          ),
        ),
      );
      return;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: mapHttpError(err),
        response: err.response,
        type: err.type,
      ),
    );
  }
}

/// Traduit une réponse HTTP d'erreur en [AppException] typée. Seule source de
/// vérité pour le statut : `OfflineSyncService.isDefinitiveRejection` et le
/// catalogue d'erreurs raisonnent ensuite sur le type, jamais sur le code HTTP.
@visibleForTesting
AppException mapHttpError(DioException err) {
  final l = AppL10n.current;
  final statusCode = err.response?.statusCode;
  final data = err.response?.data;
  final detail = data is Map ? data['detail'] as String? : null;
  // Back-end RFC 7807 ProblemDetail uses `code` (set via problem.setProperty("code", ...)).
  // We keep `errorCode` as a legacy fallback for any older endpoint.
  final apiCode = data is Map
      ? (data['code'] as String?) ?? (data['errorCode'] as String?)
      : null;
  // ProblemDetail RFC 7807 : `violations` = { champ: message } (backend).
  final rawViolations = data is Map ? data['violations'] : null;
  final Map<String, List<String>>? violations = rawViolations is Map
      ? rawViolations.map(
          (key, value) => MapEntry(key.toString(), [value.toString()]),
        )
      : null;

  if (statusCode == 400) {
    // Requête malformée refusée pour de bon par le back (corps illisible,
    // paramètre invalide) : même famille que le 422. Classé « réseau »
    // auparavant, donc rejoué sans fin par la file hors-ligne.
    return ValidationException(
      detail ?? l.networkFallbackInvalidRequest,
      code: apiCode,
      errors: violations,
    );
  }
  if (statusCode == 401) {
    return UnauthorizedException(detail ?? l.networkFallbackSessionExpired, apiCode);
  }
  if (statusCode == 403) {
    return ForbiddenException(detail ?? l.networkFallbackAccessDenied, apiCode);
  }
  if (statusCode == 404) {
    return NotFoundException(
      message: detail ?? l.networkFallbackNotFound,
      apiCode: apiCode,
    );
  }
  if (statusCode == 409) {
    return ConflictException(detail ?? l.networkFallbackConflict, code: apiCode);
  }
  if (statusCode == 422) {
    return ValidationException(
      detail ?? l.networkFallbackInvalidData,
      code: apiCode,
      errors: violations,
    );
  }
  if (statusCode == 429) {
    return RateLimitException(detail ?? l.networkFallbackTooManyAttempts);
  }
  if (statusCode != null && statusCode >= 500) {
    return ServerException(detail ?? l.networkFallbackServerError, apiCode);
  }
  return NetworkException(
    detail ?? err.message ?? l.networkFallbackNetworkError,
    code: apiCode ?? statusCode?.toString(),
  );
}
