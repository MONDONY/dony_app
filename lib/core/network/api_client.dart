import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/accept_language_interceptor.dart';
import 'package:dony/core/network/metrics_interceptor.dart';
import 'package:dony/core/network/offline_fast_fail_interceptor.dart';
import 'package:dony/core/network/retry_on_rate_limit_interceptor.dart';
import 'package:dony/core/network/retry_on_transient_error_interceptor.dart';
import 'package:dony/core/network/retry_policy.dart';
import 'package:dony/core/network/tls_pinned_ca.dart';
import 'package:dony/core/network/transport_failure.dart';
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

/// Fournit le jeton Firebase de l'utilisateur connecté, `null` sans session.
abstract interface class AuthTokenSource {
  Future<String?> idToken({required bool forceRefresh});
}

class FirebaseAuthTokenSource implements AuthTokenSource {
  const FirebaseAuthTokenSource();

  @override
  Future<String?> idToken({required bool forceRefresh}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    required DeviceIdService deviceIdService,
    ErrorReportingService? errorReporter,
    @visibleForTesting
    AuthTokenSource tokenSource = const FirebaseAuthTokenSource(),
    @visibleForTesting Connectivity? connectivity,
    @visibleForTesting RetrySleep? retrySleep,
    @visibleForTesting void Function(Breadcrumb)? breadcrumbSink,
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

    // ORDRE DE LA CHAÎNE (FLUTTER-J1). dio 5 appelle les onError dans l'ordre
    // d'ajout (dio_mixin.dart : « execute in FIFO order »), et chaque onError
    // DOIT finir par `handler.next(err)` pour passer la main : en dio 5.9,
    // `ErrorInterceptorHandler.reject` arrête la chaîne. _AuthInterceptor
    // rejetait ainsi toutes les erreurs depuis des mois, si bien qu'aucun
    // breadcrumb, aucun retry et aucun report Sentry ne voyait jamais un échec.
    //
    //  1. OfflineFastFail : coupe sans attendre quand l'appareil n'a aucune
    //     interface (rejet en onRequest, hors chaîne d'erreur, volontairement).
    //  2. AcceptLanguage.
    //  3. Breadcrumb : observe CHAQUE tentative, erreur brute (statut seul).
    //  4. Auth : jeton en onRequest ; en onError, conversion en AppException,
    //     une fois par tentative, et sur 401 un seul rafraîchissement du jeton.
    //  5. Journal debug, métriques.
    //  6. Retry 429, puis retry transitoire (5xx, timeouts, connexion) : ils
    //     relisent `response` et `type`, conservés par la conversion, et ne
    //     rejouent que les requêtes rejouables (RetryPolicy.isReplayable).
    //  7. Report Sentry, en dernier : ne voit que l'échec final.
    //
    // Une relance refait toute la chaîne sur une copie des options marquée
    // d'une profondeur (RetryPolicy.replayRequest) : la tentative imbriquée a
    // son breadcrumb et sa conversion, mais son report Sentry est sauté ; seul
    // l'échec final, rendu à la profondeur 0, est rapporté.
    _dio.interceptors.add(
      OfflineFastFailInterceptor(connectivity ?? Connectivity()),
    );
    _dio.interceptors.add(AcceptLanguageInterceptor());

    // Piste HTTP dans Sentry (breadcrumbs) — active en tout mode, mais no-op
    // tant que SENTRY_DSN est absent. On ne pousse QUE méthode + chemin
    // normalisé + statut : jamais les corps ni les en-têtes (tokens Firebase,
    // secrets Stripe, KYC).
    _dio.interceptors.add(
      _SentryBreadcrumbInterceptor(breadcrumbSink ?? _addSentryBreadcrumb),
    );
    _dio.interceptors.add(_AuthInterceptor(deviceIdService, tokenSource, _dio));

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

    // Les onError s'enchaînent dans l'ordre d'ajout : _AuthInterceptor, placé
    // avant, a déjà converti l'erreur en AppException, en conservant
    // `response` et `type` que les retries relisent (429, timeouts, 5xx).
    _dio.interceptors.add(RetryOnRateLimitInterceptor(_dio, sleep: retrySleep));
    _dio.interceptors.add(
      RetryOnTransientErrorInterceptor(_dio, sleep: retrySleep),
    );

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

/// Rapporte à Sentry l'échec FINAL d'une requête, sans inonder :
///  - une tentative imbriquée (relance en cours) n'est jamais rapportée ;
///  - les échecs de transport (annulation, délais, connexion impossible) non
///    plus : ils viennent du réseau de l'appareil, l'écran le dit déjà ;
///  - les codes métier attendus (401, 403, 404, 409, 422, 429) sont écartés
///    par [ErrorReportingService] ;
///  - une même panne (méthode, chemin normalisé, statut, code) part au plus
///    une fois par [throttleWindow] ; une panne transitoire (502/503/504) une
///    fois par statut, toutes routes confondues, sous l'empreinte
///    `http-transient-<statut>` (la route reste en tag).
/// Rien d'autre que méthode, chemin normalisé et code ne part : ni corps, ni
/// en-têtes, ni message brut (voir [ErrorReportingService]).
class _SentryErrorReportingInterceptor extends Interceptor {
  _SentryErrorReportingInterceptor(this._reporter);

  final ErrorReportingService _reporter;
  final Map<String, DateTime> _lastReported = {};

  static const throttleWindow = Duration(minutes: 10);

  static const _transportTypes = {
    DioExceptionType.cancel,
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
  };

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_shouldReport(err)) {
      final options = err.requestOptions;
      unawaited(
        _reporter.report(
          err,
          operation: 'http.${options.method.toUpperCase()}',
          stackTrace: err.stackTrace,
          statusCode: err.response?.statusCode,
          context: {
            'method': options.method.toUpperCase(),
            'endpoint': options.uri.path,
            'feature': _featureForPath(options.uri.path),
            'retry_count': RetryPolicy.retryCountOf(options),
          },
        ),
      );
    }
    handler.next(err);
  }

  bool _shouldReport(DioException err) {
    final options = err.requestOptions;
    if (RetryPolicy.depthOf(options) > 0) return false;
    if (_transportTypes.contains(err.type)) return false;
    // Connexion perdue sans réponse, levée en `unknown` (socket coupée par
    // Android en arrière-plan) : même famille que les délais (FLUTTER-JQ).
    if (isTransportFailure(err)) return false;
    final inner = err.error;
    // Panne transitoire (502/503/504, API injoignable) : une seule clé pour
    // toutes les routes, comme son empreinte Sentry. Un redémarrage de l'API
    // produit un événement, pas un par route.
    final transient = ErrorReportingService.transientFingerprint(
      err,
      err.response?.statusCode,
    );
    final key =
        transient ??
        '${options.method.toUpperCase()} '
            '${ErrorReportingService.normalizeEndpoint(options.uri.path)} '
            '${err.response?.statusCode ?? err.type.name} '
            '${inner is AppException ? inner.code : ''}';
    final now = DateTime.now();
    final last = _lastReported[key];
    if (last != null && now.difference(last) < throttleWindow) return false;
    _lastReported[key] = now;
    return true;
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
void _addSentryBreadcrumb(Breadcrumb crumb) {
  unawaited(Sentry.addBreadcrumb(crumb));
}

class _SentryBreadcrumbInterceptor extends Interceptor {
  _SentryBreadcrumbInterceptor(this._sink);

  final void Function(Breadcrumb) _sink;

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
    _sink(
      Breadcrumb(
        category: 'http',
        type: 'http',
        level: level,
        data: {
          'method': options.method,
          'path': ErrorReportingService.normalizeEndpoint(options.uri.path),
          'status_code': ?status,
        },
      ),
    );
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._deviceIdService, this._tokenSource, this._dio);

  final DeviceIdService _deviceIdService;
  final AuthTokenSource _tokenSource;
  final Dio _dio;

  /// Rafraîchissement en cours, partagé : dix requêtes en 401 au même instant
  /// ne forcent qu'un seul aller-retour vers Firebase.
  Future<String?>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final isCritical =
          options.path.contains('/payments') ||
          options.path.contains('/kyc') ||
          options.path.contains('/tracking/events') ||
          options.path.contains('/bids/checkout');
      final token = await _tokenSource.idToken(forceRefresh: isCritical);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
        try {
          options.headers['X-Device-Id'] = await _deviceIdService.getDeviceId();
        } on DeviceIdUnavailableException {
          // Trousseau verrouillé (app réveillée en arrière-plan) : la requête
          // part sans l'en-tête, seul l'écran Appareils connectés l'exige.
        }
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
            'Authentification impossible', // i18n-ignore : catalogue résout 'auth-token-unavailable'
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
            'Authentification impossible', // i18n-ignore : catalogue résout 'auth-token-unavailable'
            'auth-token-unavailable',
          ),
        ),
      );
      return;
    }
    handler.next(options);
  }

  /// Convertit l'erreur en [AppException] (une fois par tentative) et la
  /// PASSE à l'intercepteur suivant : `handler.reject` arrêterait la chaîne
  /// (FLUTTER-J1).
  ///
  /// Sur un 401 d'une requête qui portait un jeton, le jeton est rafraîchi une
  /// seule fois (drapeau [RetryPolicy.authRefreshedKey] sur la relance, jamais
  /// de boucle). La requête n'est rejouée que si elle est rejouable : une
  /// écriture sans clé d'idempotence remonte son 401, la suivante partira avec
  /// le jeton neuf.
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final mapped = err.copyWith(error: mapHttpError(err));
    final options = err.requestOptions;
    if (err.response?.statusCode == 401 &&
        options.extra[RetryPolicy.authRefreshedKey] != true &&
        options.headers.containsKey('Authorization')) {
      final fresh = await _refreshToken();
      if (fresh != null && RetryPolicy.isReplayable(options)) {
        await RetryPolicy.replayRequest(
          _dio,
          mapped,
          handler,
          extra: {RetryPolicy.authRefreshedKey: true},
        );
        return;
      }
    }
    handler.next(mapped);
  }

  Future<String?> _refreshToken() {
    return _refreshing ??= _tokenSource
        .idToken(forceRefresh: true)
        .then<String?>((t) => t, onError: (Object _) => null)
        .whenComplete(() => _refreshing = null);
  }
}

/// Traduit une réponse HTTP d'erreur en [AppException] typée. Seule source de
/// vérité pour le statut : `OfflineSyncService.isDefinitiveRejection` et le
/// catalogue d'erreurs raisonnent ensuite sur le type, jamais sur le code HTTP.
@visibleForTesting
AppException mapHttpError(DioException err) {
  final inner = err.error;
  // Déjà convertie (rejet typé d'un intercepteur, erreur d'une relance).
  if (inner is AppException) return inner;
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
    return UnauthorizedException(
      detail ?? l.networkFallbackSessionExpired,
      apiCode,
    );
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
    return ConflictException(
      detail ?? l.networkFallbackConflict,
      code: apiCode,
    );
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
  // Passerelle ou API indisponible (redémarrage, déploiement : FLUTTER-J1).
  if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
    return ServiceUnavailableException(
      detail ?? l.errorServiceUnavailableMessage,
      apiCode,
    );
  }
  if (statusCode != null && statusCode >= 500) {
    return ServerException(detail ?? l.networkFallbackServerError, apiCode);
  }
  if (statusCode == null) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException();
      case DioExceptionType.connectionError:
        // Une interface réseau existe (sinon OfflineFastFailInterceptor aurait
        // coupé avant) mais l'API ne répond pas : service indisponible.
        return ServiceUnavailableException(l.errorServiceUnavailableMessage);
      case DioExceptionType.cancel:
        return const NetworkException(
          'Requête annulée', // i18n-ignore : catalogue résout 'CANCELLED'
          code: 'CANCELLED',
        );
      case DioExceptionType.unknown when isTransportError(err.error):
        // Socket coupée sans réponse (Android en arrière-plan, réseau perdu
        // en route) : tombait en NetworkException sans code, rapportée sous
        // « ReportedError(http.GET, DioException) » (FLUTTER-JQ).
        return const OfflineException();
      default:
        break;
    }
  }
  return NetworkException(
    detail ?? err.message ?? l.networkFallbackNetworkError,
    code: apiCode ?? statusCode?.toString(),
  );
}
