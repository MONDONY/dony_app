import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/transport_failure.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sentry_flutter/sentry_flutter.dart';

/// Small abstraction used to test error reporting without booting Sentry.
abstract interface class ErrorReportingSink {
  Future<void> capture(
    Object error, {
    StackTrace? stackTrace,
    required Map<String, Object> context,
  });
}

class SentryErrorReportingSink implements ErrorReportingSink {
  const SentryErrorReportingSink();

  @override
  Future<void> capture(
    Object error, {
    StackTrace? stackTrace,
    required Map<String, Object> context,
  }) async {
    // Le contexte passe par le scope de l'événement : un `Hint` n'est lu que
    // par les callbacks locaux (beforeSend) et n'est jamais envoyé, si bien
    // que stripe_code / decline_code / stripe_message n'atteignaient jamais
    // Sentry (FLUTTER-CJ). Le scope cloné par `withScope` n'est pas
    // synchronisé vers le natif : rien ne fuit vers les événements suivants.
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) => applyReportContext(scope, context),
    );
  }

  /// Clés du contexte promues en tags, pour filtrer et regrouper dans Sentry.
  /// Toutes sont des codes fermés ; `stripe_message` reste dans le contexte.
  static const taggedKeys = {
    'operation',
    'error_type',
    'status_code',
    // Route normalisée (`/api/v1/bids/:id`) : une panne transitoire est
    // regroupée sans elle (empreinte [fingerprintKey]), elle reste filtrable.
    'endpoint',
    'stripe_code',
    'stripe_error_code',
    'decline_code',
    'stripe_error_type',
  };

  /// Nom du bloc de contexte visible dans l'événement Sentry.
  static const contextKey = 'yadony';

  /// Clé réservée du contexte : empreinte Sentry imposée à l'événement (voir
  /// [ErrorReportingService.transientFingerprint]). Jamais envoyée en contexte.
  static const fingerprintKey = '_fingerprint';

  @visibleForTesting
  static Future<void> applyReportContext(
    Scope scope,
    Map<String, Object> context,
  ) async {
    final fingerprint = context[fingerprintKey];
    if (fingerprint is String) scope.fingerprint = [fingerprint];
    final visible = Map<String, Object>.of(context)..remove(fingerprintKey);
    await scope.setContexts(contextKey, visible);
    for (final entry in visible.entries) {
      if (taggedKeys.contains(entry.key)) {
        await scope.setTag(entry.key, entry.value.toString());
      }
    }
  }
}

/// Captures only actionable failures and deliberately discards raw exception
/// messages. Backend details can contain addresses, phone numbers or secrets.
class ErrorReportingService {
  ErrorReportingService(this._sink);

  final ErrorReportingSink _sink;

  // 429 : réponse normale du rate-limiting nginx (5 req/min sur /auth et
  // /kyc) — un poll qui tombe dessus n'est pas un bug à remonter.
  static const _expectedStatusCodes = {401, 403, 404, 409, 422, 429};
  // OFFLINE / TIMEOUT : l'appareil n'a pas de réseau ou le perd en route. Ce
  // n'est pas un défaut de l'app, l'écran affiche déjà le message adapté, et
  // un utilisateur en 2G en produisait une salve à chaque parcours KYC.
  static const _expectedCodes = {
    'UNAUTHORIZED',
    'FORBIDDEN',
    'NOT_FOUND',
    'CONFLICT',
    'CANCELLED',
    'RATE_LIMITED',
    'OFFLINE',
    'TIMEOUT',
  };

  /// Refus métier attendus d'une saisie de l'utilisateur, envoyés en 400 par
  /// le back : l'écran les explique, ce ne sont pas des défauts de l'app
  /// (FLUTTER-JP : code OTP faux).
  static const _expectedBusinessCodes = {
    'phone-otp-invalid',
    'phone-otp-expired',
    'otp-invalid',
    'otp-expired',
  };

  /// Statuts d'une API momentanément indisponible (redémarrage, déploiement).
  static const transientStatusCodes = {502, 503, 504};

  /// Empreinte commune d'une panne transitoire, SANS la route : un
  /// redémarrage de l'API staging ouvrait ~25 issues, une par route
  /// (`ReportedError(http.GET, DioException, SERVICE_UNAVAILABLE)`). `null`
  /// si l'erreur n'est pas transitoire.
  static String? transientFingerprint(Object error, int? statusCode) {
    if (statusCode != null && transientStatusCodes.contains(statusCode)) {
      return 'http-transient-$statusCode';
    }
    final appError = error is DioException ? error.error : error;
    if (appError is ServiceUnavailableException) {
      return 'http-transient-${statusCode ?? 'network'}';
    }
    return null;
  }

  Future<void> report(
    Object error, {
    required String operation,
    StackTrace? stackTrace,
    int? statusCode,
    Map<String, Object>? context,
  }) async {
    final effectiveStatusCode =
        statusCode ??
        (error is DioException ? error.response?.statusCode : null);
    if (_isExpected(error, effectiveStatusCode)) return;

    final safeContext = <String, Object>{
      'operation': operation,
      'error_type': error.runtimeType.toString(),
      'status_code': ?effectiveStatusCode,
      ..._safeContext(context),
      SentryErrorReportingSink.fingerprintKey: ?transientFingerprint(
        error,
        effectiveStatusCode,
      ),
    };

    // Keep the original stack while replacing its potentially sensitive text.
    await _sink.capture(
      _ReportedError(
        operation: operation,
        errorType: error.runtimeType.toString(),
        code: _safeCode(error),
      ),
      stackTrace: stackTrace,
      context: safeContext,
    );
  }

  /// Code d'erreur sans donnée personnelle : le code métier d'une
  /// [AppException], ou le code fermé d'une [FirebaseException]
  /// (`apns-token-not-set`, `unknown`…). Sans lui, tous les échecs Firebase se
  /// regroupaient sous un même titre impossible à diagnostiquer.
  static String? _safeCode(Object error) => switch (error) {
    AppException(:final code) => code,
    // L'intercepteur HTTP passe la DioException brute ; l'AppException produite
    // par mapHttpError est dans `.error`. Sans ce cas, aucun code métier
    // n'atteignait Sentry et tout se regroupait sous « http.POST, DioException ».
    DioException(:final error) when error is AppException => error.code,
    FirebaseException(:final code) => code,
    _ => null,
  };

  static bool _isExpected(Object error, int? statusCode) {
    if (statusCode != null && _expectedStatusCodes.contains(statusCode)) {
      return true;
    }
    // Échec sans réponse venu du réseau de l'appareil (hors ligne, délai,
    // socket coupée en arrière-plan) : jamais un défaut de l'app, quel que
    // soit l'état de l'application (FLUTTER-JQ).
    if (statusCode == null &&
        error is DioException &&
        isTransportFailure(error)) {
      return true;
    }
    // L'intercepteur HTTP passe la DioException : l'AppException convertie
    // est dans `.error`. Sans ce dépliage, un délai dépassé (TIMEOUT) ou une
    // annulation (CANCELLED) seraient rapportés.
    final appError = error is DioException ? error.error : error;
    return appError is AppException &&
        (_expectedCodes.contains(appError.code) ||
            _expectedBusinessCodes.contains(appError.code));
  }

  static Map<String, Object> _safeContext(Map<String, Object>? context) {
    if (context == null) return const {};
    const allowed = {
      'method',
      'feature',
      'endpoint',
      'retry_count',
      'channel',
      'apns_token_available',
      'platform',
      'attempts',
      // Échec Stripe (FLUTTER-7S) : codes fermés du SDK et message brut,
      // générique, de Stripe (« Your card was declined. »), sans donnée de
      // carte ni d'identité.
      'stripe_code',
      'stripe_error_code',
      'decline_code',
      'stripe_error_type',
      'stripe_message',
    };
    final output = <String, Object>{};
    for (final entry in context.entries) {
      if (!allowed.contains(entry.key)) continue;
      final value = entry.value;
      if (entry.key == 'endpoint' && value is String) {
        output[entry.key] = normalizeEndpoint(value);
      } else if (value is String || value is num || value is bool) {
        output[entry.key] = value;
      }
    }
    return output;
  }

  static String normalizeEndpoint(String endpoint) => endpoint
      .split('?')
      .first
      .replaceAll(RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,}'), ':id')
      // Segment opaque long contenant un chiffre (jeton de suivi, code) :
      // jamais un mot de route, qui n'a pas de chiffre.
      .replaceAll(RegExp(r'/(?=[A-Za-z_-]*\d)[A-Za-z0-9_-]{20,}'), '/:token')
      .replaceAll(RegExp(r'/\+?\d+'), '/:id');
}

class _ReportedError implements Exception {
  const _ReportedError({
    required this.operation,
    required this.errorType,
    this.code,
  });

  final String operation;
  final String errorType;
  final String? code;

  @override
  String toString() =>
      'ReportedError($operation, $errorType${code == null ? '' : ', $code'})';
}
