import 'dart:io'
    show
        HandshakeException,
        HttpException,
        OSError,
        SocketException,
        TlsException;

import 'package:dio/dio.dart';

/// La requête a-t-elle échoué AVANT toute réponse, à cause du réseau de
/// l'appareil (connexion coupée, socket fermée, appareil hors ligne) ?
///
/// dio classe ces pannes en `DioExceptionType.unknown` quand l'adaptateur
/// lève une erreur `dart:io` brute : Android coupe les sockets d'une
/// application qui passe en arrière-plan (`SocketException: Software caused
/// connection abort`, `HttpException: Connection closed before full header
/// was received`). Sans ce test, l'erreur tombait en `NetworkException` sans
/// code et partait dans Sentry sous « ReportedError(http.GET, DioException) »
/// (FLUTTER-JQ).
///
/// Un échec de vérification du certificat n'en est PAS un : l'épinglage TLS
/// doit rester visible.
bool isTransportFailure(DioException err) {
  if (err.response != null) return false;
  switch (err.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return true;
    case DioExceptionType.unknown:
      return isTransportError(err.error);
    case DioExceptionType.badCertificate:
    case DioExceptionType.badResponse:
    case DioExceptionType.cancel:
      return false;
  }
}

/// Erreur `dart:io` d'une connexion perdue, hors refus de certificat.
bool isTransportError(Object? error) => switch (error) {
  SocketException() => true,
  HttpException() => true,
  HandshakeException(:final message, :final osError) => !_isCertificateFailure(
    '$message ${osError?.message ?? ''}',
  ),
  _ => false,
};

bool _isCertificateFailure(String text) =>
    text.toUpperCase().contains('CERTIFICATE');

/// Clé de `RequestOptions.extra` : type de l'erreur levée par l'adaptateur,
/// AVANT sa conversion en [AppException] par l'intercepteur d'authentification.
/// Sans elle, Sentry ne voyait que la `NetworkException` convertie et un échec
/// sans réponse restait impossible à diagnostiquer (FLUTTER-QC, FLUTTER-K3).
const originalErrorTypeKey = '_originalErrorType';

/// Clé de `RequestOptions.extra` : `true` si la requête a échoué parce que le
/// certificat du serveur a été refusé (épinglage TLS, chaîne non reconnue).
const certificateRejectedKey = '_certificateRejected';

/// Note, sur les options de la requête, ce que la conversion en
/// [AppException] va effacer : le type de l'erreur d'origine et un éventuel
/// refus de certificat. Appelée avant la conversion, à chaque tentative : une
/// relance remplace donc les valeurs de la tentative précédente.
void rememberOriginalError(DioException err) {
  err.requestOptions.extra
    ..[originalErrorTypeKey] = describeErrorType(err.error)
    ..[certificateRejectedKey] = _rejectsCertificate(err);
}

/// Type de l'erreur d'origine d'un échec Dio, pour Sentry : celui noté par
/// [rememberOriginalError], sinon celui de `err.error`.
String originalErrorTypeOf(DioException err) =>
    err.requestOptions.extra[originalErrorTypeKey] as String? ??
    describeErrorType(err.error);

/// Le certificat du serveur a-t-il été refusé ? Un tel échec doit rester
/// visible dans Sentry (épinglage TLS), mais en une seule issue.
bool isCertificateFailure(DioException err) =>
    err.response == null &&
    (err.requestOptions.extra[certificateRejectedKey] == true ||
        _rejectsCertificate(err));

bool _rejectsCertificate(DioException err) {
  if (err.response != null) return false;
  if (err.type == DioExceptionType.badCertificate) return true;
  final inner = err.error;
  return err.type == DioExceptionType.unknown &&
      inner is TlsException &&
      _isCertificateFailure('${inner.message} ${inner.osError?.message ?? ''}');
}

/// Nom stable du type d'une erreur, sans son message. Les types `dart:io`
/// attendus sont nommés en dur : le build obfusqué renomme `runtimeType`.
String describeErrorType(Object? error) => switch (error) {
  null => 'none',
  HandshakeException() => 'HandshakeException',
  TlsException() => 'TlsException',
  SocketException() => 'SocketException',
  HttpException() => 'HttpException',
  OSError() => 'OSError',
  _ => error.runtimeType.toString(),
};
