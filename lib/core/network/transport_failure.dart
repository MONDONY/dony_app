import 'dart:io' show HandshakeException, HttpException, SocketException;

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
