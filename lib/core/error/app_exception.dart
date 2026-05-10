import 'package:dio/dio.dart' show DioException, DioExceptionType;
import 'package:equatable/equatable.dart';

/// Extracts an [AppException] stored inside a [DioException.error] by the
/// auth interceptor, or wraps any other error in the most accurate subtype.
AppException unwrapDioError(Object e) {
  if (e is AppException) return e;
  if (e is DioException) {
    final inner = e.error;
    if (inner is AppException) return inner;
    // Connection failures don't go through onError mapping (no response).
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException();
      case DioExceptionType.connectionError:
        return const OfflineException();
      case DioExceptionType.cancel:
        return const NetworkException('Requête annulée', code: 'CANCELLED');
      default:
        return NetworkException(e.message ?? 'Erreur réseau');
    }
  }
  return NetworkException(e.toString());
}

/// Base type for all errors raised inside the app. Always carries:
/// - [message] : raw detail (often the back-end's `detail` field, in EN/FR).
/// - [code]    : business code from the back-end ProblemDetail (`deletion-impossible`,
///               `code-expired`, …) OR a synthetic code for transport errors
///               (`OFFLINE`, `TIMEOUT`, `SERVER_ERROR`, …).
///
/// UI must NEVER display [message] directly — use `ErrorPresenter.show()`,
/// which resolves the code through `ErrorCatalog` and falls back gracefully.
abstract class AppException extends Equatable implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => 'AppException($code): $message';
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code});
}

class TimeoutException extends AppException {
  const TimeoutException([super.message = 'Délai dépassé'])
      : super(code: 'TIMEOUT');
}

class OfflineException extends AppException {
  const OfflineException([super.message = 'Pas de connexion'])
      : super(code: 'OFFLINE');
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Unauthorized', String? apiCode])
      : super(code: apiCode ?? 'UNAUTHORIZED');
}

class ForbiddenException extends AppException {
  const ForbiddenException([String message = 'Forbidden', String? apiCode])
      : super(message, code: apiCode ?? 'FORBIDDEN');
}

class NotFoundException extends AppException {
  const NotFoundException({
    String message = 'Ressource introuvable',
    String? apiCode,
    this.resourceType,
  }) : super(message, code: apiCode ?? 'NOT_FOUND');

  final String? resourceType;

  @override
  List<Object?> get props => [message, code, resourceType];
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, this.errors});

  final Map<String, List<String>>? errors;

  @override
  List<Object?> get props => [message, code, errors];
}

class ConflictException extends AppException {
  const ConflictException(super.message, {super.code});
}

class RateLimitException extends AppException {
  const RateLimitException([super.message = 'Trop de tentatives'])
      : super(code: 'RATE_LIMITED');
}

class ServerException extends AppException {
  const ServerException([super.message = 'Server error', String? apiCode])
      : super(code: apiCode ?? 'SERVER_ERROR');
}

class StorageException extends AppException {
  const StorageException(super.message, {super.code});
}
