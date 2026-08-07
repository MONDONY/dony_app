import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/metrics_interceptor.dart';
import 'package:dony/core/network/retry_on_rate_limit_interceptor.dart';
import 'package:dony/core/network/retry_on_transient_error_interceptor.dart';
import 'package:dony/core/services/device_id_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// PEM certificate for production TLS pinning.
// Populated at build time via --dart-define-from-file=env.prod.json:
//   "TLS_CERT_PEM": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----\n"
// How to obtain: openssl s_client -connect api.dony.app:443 -servername api.dony.app \
//                  </dev/null 2>/dev/null | openssl x509 -outform PEM
// Leave empty in env.dev.json — pinning is always skipped in debug mode.
const _tlsCertPem = String.fromEnvironment('TLS_CERT_PEM');

class ApiClient {
  ApiClient({required String baseUrl, required DeviceIdService deviceIdService}) {
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
      _dio.interceptors.add(MetricsInterceptor(MetricsInterceptor.globalCollector));
    }

    // Ajouté en dernier : dans le sens onError (inverse de l'ajout), c'est le
    // premier à voir l'erreur brute — avant que _AuthInterceptor ne la
    // convertisse en RateLimitException — donc le mieux placé pour retenter
    // la requête d'origine avant que quiconque en aval ne l'affiche à l'utilisateur.
    _dio.interceptors.add(RetryOnRateLimitInterceptor(_dio));

    // Ajouté en tout dernier pour la même raison : voir l'erreur brute avant
    // toute conversion, afin de retenter les GET sur timeout/erreur de
    // connexion/5xx (cold-start backend) avant que _AuthInterceptor ne les
    // transforme en AppException.
    _dio.interceptors.add(RetryOnTransientErrorInterceptor(_dio));
  }

  late final Dio _dio;

  Dio get dio => _dio;

  // Installs a custom SecurityContext that trusts ONLY the pinned server cert,
  // rejecting any connection to a server presenting a different certificate —
  // even if that certificate is signed by a trusted CA (MITM protection).
  //
  // Pinning is intentionally skipped when:
  //   • running in debug mode (allows Charles/mitmproxy during dev)
  //   • _tlsCertPem is empty (env.dev.json default — no pin configured)
  //   • running on web (dart:io not available)
  void _configureCertificatePinning() {
    if (kIsWeb || kDebugMode || _tlsCertPem.isEmpty) return;
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final context = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificatesBytes(const Utf8Encoder().convert(_tlsCertPem));
      return HttpClient(context: context);
    };
  }
}

/// Émet un breadcrumb Sentry par réponse/erreur HTTP. PII-free : uniquement
/// méthode, chemin (sans query string) et code de statut. Ces miettes forment
/// la piste réseau attachée au prochain incident capturé.
class _SentryBreadcrumbInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _crumb(
      response.requestOptions,
      response.statusCode,
      SentryLevel.info,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    _crumb(
      err.requestOptions,
      status,
      (status != null && status < 500) ? SentryLevel.warning : SentryLevel.error,
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
          if (status != null) 'status_code': status,
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
    // Skip auth for public endpoints (e.g. health check before Firebase is ready)
    if (options.extra['skipAuth'] == true) {
      handler.next(options);
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final isCritical = options.path.contains('/payments') ||
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
      // Any other Firebase error should NOT silently proceed.
      handler.reject(
        DioException(
          requestOptions: options,
          error: 'Authentication failed: ${e.message}',
          type: DioExceptionType.unknown,
        ),
      );
      return;
    } catch (e) {
      // Unexpected error — reject instead of silently proceeding.
      handler.reject(
        DioException(
          requestOptions: options,
          error: 'Unexpected auth error',
          type: DioExceptionType.unknown,
        ),
      );
      return;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    final data = err.response?.data;
    final detail = data is Map ? data['detail'] as String? : null;
    // Back-end RFC 7807 ProblemDetail uses `code` (set via problem.setProperty("code", ...)).
    // We keep `errorCode` as a legacy fallback for any older endpoint.
    final apiCode = data is Map
        ? (data['code'] as String?) ?? (data['errorCode'] as String?)
        : null;

    final AppException appException;
    if (statusCode == 401) {
      appException = UnauthorizedException(detail ?? 'Session expirée', apiCode);
    } else if (statusCode == 403) {
      appException = ForbiddenException(detail ?? 'Accès refusé', apiCode);
    } else if (statusCode == 404) {
      appException = NotFoundException(
        message: detail ?? 'Ressource introuvable',
        apiCode: apiCode,
      );
    } else if (statusCode == 409) {
      appException = ConflictException(detail ?? 'Conflit', code: apiCode);
    } else if (statusCode == 422) {
      // ProblemDetail RFC 7807 : `violations` = { champ: message } (backend).
      final rawViolations = data is Map ? data['violations'] : null;
      final Map<String, List<String>>? violations = rawViolations is Map
          ? rawViolations.map(
              (key, value) => MapEntry(key.toString(), [value.toString()]))
          : null;
      appException = ValidationException(
        detail ?? 'Données invalides',
        code: apiCode,
        errors: violations,
      );
    } else if (statusCode == 429) {
      appException = RateLimitException(detail ?? 'Trop de tentatives');
    } else if (statusCode != null && statusCode >= 500) {
      appException = ServerException(detail ?? 'Erreur serveur', apiCode);
    } else {
      appException = NetworkException(
        detail ?? err.message ?? 'Erreur réseau',
        code: apiCode ?? statusCode?.toString(),
      );
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: appException,
        response: err.response,
        type: err.type,
      ),
    );
  }
}
