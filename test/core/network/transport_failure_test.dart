import 'dart:io'
    show HandshakeException, HttpException, OSError, SocketException;

import 'package:dio/dio.dart';
import 'package:dony/core/network/transport_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final options = RequestOptions(path: '/x');

  DioException dio(DioExceptionType type, {Object? error, int? status}) =>
      DioException(
        requestOptions: options,
        type: type,
        error: error,
        response: status == null
            ? null
            : Response(requestOptions: options, statusCode: status),
      );

  group('isTransportFailure', () {
    test('délais et connexion impossible : panne réseau', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        expect(isTransportFailure(dio(type)), isTrue, reason: type.name);
      }
    });

    test('unknown : selon l\'erreur dart:io portée', () {
      expect(
        isTransportFailure(
          dio(DioExceptionType.unknown, error: const SocketException('x')),
        ),
        isTrue,
      );
      expect(
        isTransportFailure(
          dio(DioExceptionType.unknown, error: StateError('x')),
        ),
        isFalse,
      );
    });

    test('réponse reçue, annulation, certificat : jamais une panne réseau', () {
      expect(
        isTransportFailure(dio(DioExceptionType.badResponse, status: 500)),
        isFalse,
      );
      expect(
        isTransportFailure(dio(DioExceptionType.connectionError, status: 502)),
        isFalse,
      );
      expect(isTransportFailure(dio(DioExceptionType.cancel)), isFalse);
      expect(isTransportFailure(dio(DioExceptionType.badCertificate)), isFalse);
    });
  });

  group('isTransportError', () {
    test('socket et connexion fermée', () {
      expect(isTransportError(const SocketException('x')), isTrue);
      expect(
        isTransportError(const HttpException('Connection closed')),
        isTrue,
      );
    });

    test('poignée de main coupée, mais pas un certificat refusé', () {
      expect(
        isTransportError(const HandshakeException('Connection terminated')),
        isTrue,
      );
      expect(
        isTransportError(
          const HandshakeException(
            'Handshake error: CERTIFICATE_VERIFY_FAILED',
          ),
        ),
        isFalse,
      );
      expect(
        isTransportError(
          const HandshakeException(
            'Handshake error',
            OSError('certificate verify failed', 1),
          ),
        ),
        isFalse,
      );
    });

    test('autre erreur ou rien : non', () {
      expect(isTransportError(null), isFalse);
      expect(isTransportError('Connection refused'), isFalse);
    });
  });
}
