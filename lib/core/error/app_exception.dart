import 'package:dio/dio.dart' show DioException;
import 'package:equatable/equatable.dart';

/// Extracts an [AppException] stored inside a [DioException.error] by the
/// auth interceptor, or wraps any other error in [NetworkException].
AppException unwrapDioError(Object e) {
  if (e is AppException) {
    return e;
  }
  if (e is DioException) {
    final inner = e.error;
    if (inner is AppException) {
      return inner;
    }
    return NetworkException(e.message ?? 'Erreur réseau');
  }
  return NetworkException(e.toString());
}

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

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Unauthorized'])
      : super(code: 'UNAUTHORIZED');
}

class ForbiddenException extends AppException {
  ForbiddenException([String message = 'Forbidden', String? apiCode])
      : super(message, code: apiCode ?? 'FORBIDDEN');
}

class NotFoundException extends AppException {
  const NotFoundException({
    String message = 'Ressource introuvable',
    this.resourceType,
  }) : super(message, code: 'NOT_FOUND');

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

class ServerException extends AppException {
  const ServerException([super.message = 'Server error'])
      : super(code: 'SERVER_ERROR');
}

class StorageException extends AppException {
  const StorageException(super.message, {super.code});
}
