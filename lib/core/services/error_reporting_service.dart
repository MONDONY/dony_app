import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
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
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: Hint.withMap(context),
    );
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
    FirebaseException(:final code) => code,
    _ => null,
  };

  static bool _isExpected(Object error, int? statusCode) {
    if (statusCode != null && _expectedStatusCodes.contains(statusCode)) {
      return true;
    }
    return error is AppException && _expectedCodes.contains(error.code);
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
      .replaceAll(RegExp(r'/\d+'), '/:id');
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
