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
        // Jamais affiché PAR ErrorCatalog : ErrorCatalog.lookup résout
        // 'CANCELLED' via son propre texte localisé (errorCancelledMessage),
        // sans jamais lire AppException.message. Un écran qui affiche
        // directement `e.toString()`/`e.message` sans passer par
        // ErrorPresenter/ErrorCatalog reste hors de cette garantie (suivi
        // distinct, cf. relecture finale du lot J).
        return const NetworkException(
          'Requête annulée', // i18n-ignore
          code: 'CANCELLED',
        );
      default:
        // Jamais affiché PAR ErrorCatalog : NetworkException tombe sur
        // _networkGeneric dans ErrorCatalog (_byType), qui ignore
        // error.message. Voir la remarque ci-dessus pour un écran qui
        // contournerait ErrorCatalog.
        return NetworkException(e.message ?? 'Erreur réseau'); // i18n-ignore
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
  // Jamais affiché PAR ErrorCatalog : ErrorCatalog.lookup résout 'TIMEOUT'
  // via errorTimeoutMessage, sans jamais lire AppException.message. Un écran
  // qui affiche directement `e.toString()`/`e.message` reste hors de cette
  // garantie (suivi distinct, cf. relecture finale du lot J).
  const TimeoutException([super.message = 'Délai dépassé']) // i18n-ignore
    : super(code: 'TIMEOUT');
}

class OfflineException extends AppException {
  // Jamais affiché PAR ErrorCatalog : ErrorCatalog.lookup résout 'OFFLINE'
  // via errorOfflineMessage, sans jamais lire AppException.message. Même
  // remarque que TimeoutException pour un écran qui contournerait
  // ErrorCatalog.
  const OfflineException([super.message = 'Pas de connexion']) // i18n-ignore
    : super(code: 'OFFLINE');
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Unauthorized', String? apiCode])
    : super(code: apiCode ?? 'UNAUTHORIZED');
}

class ForbiddenException extends AppException {
  const ForbiddenException([super.message = 'Forbidden', String? apiCode])
    : super(code: apiCode ?? 'FORBIDDEN');
}

class NotFoundException extends AppException {
  // Jamais affiché PAR ErrorCatalog : ErrorCatalog._byType retombe sur
  // _notFoundGeneric (errorNotFoundMessage), sans jamais lire ce champ. Un
  // écran qui contournerait ErrorCatalog reste hors de cette garantie.
  const NotFoundException({
    String message = 'Ressource introuvable', // i18n-ignore
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
  // Jamais affiché PAR ErrorCatalog : ErrorCatalog.lookup résout
  // 'RATE_LIMITED' via errorRateLimitedMessage, sans jamais lire ce champ. Un
  // écran qui contournerait ErrorCatalog reste hors de cette garantie.
  const RateLimitException([
    super.message = 'Trop de tentatives', // i18n-ignore
  ]) : super(code: 'RATE_LIMITED');
}

class ServerException extends AppException {
  const ServerException([super.message = 'Server error', String? apiCode])
    : super(code: apiCode ?? 'SERVER_ERROR');
}

class StorageException extends AppException {
  const StorageException(super.message, {super.code});
}
