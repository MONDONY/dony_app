import 'package:dony/core/error/app_exception.dart';
import 'package:dio/dio.dart';
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

  static const _expectedStatusCodes = {401, 403, 404, 409, 422};
  static const _expectedCodes = {
    'UNAUTHORIZED',
    'FORBIDDEN',
    'NOT_FOUND',
    'CONFLICT',
    'CANCELLED',
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
      if (effectiveStatusCode != null) 'status_code': effectiveStatusCode,
      ..._safeContext(context),
    };

    // Keep the original stack while replacing its potentially sensitive text.
    await _sink.capture(
      _ReportedError(
        operation: operation,
        errorType: error.runtimeType.toString(),
        code: error is AppException ? error.code : null,
      ),
      stackTrace: stackTrace,
      context: safeContext,
    );
  }

  static bool _isExpected(Object error, int? statusCode) {
    if (statusCode != null && _expectedStatusCodes.contains(statusCode)) {
      return true;
    }
    return error is AppException && _expectedCodes.contains(error.code);
  }

  static Map<String, Object> _safeContext(Map<String, Object>? context) {
    if (context == null) return const {};
    const allowed = {'method', 'feature', 'endpoint', 'retry_count', 'channel'};
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
