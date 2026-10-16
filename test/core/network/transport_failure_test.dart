import 'dart:io'
    show
        HandshakeException,
        HttpException,
        OSError,
        SocketException,
        TlsException;

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

  group('erreur d\'origine notée avant la conversion (FLUTTER-QC)', () {
    test('describeErrorType : noms stables des erreurs dart:io', () {
      expect(describeErrorType(null), 'none');
      expect(
        describeErrorType(const HandshakeException('x')),
        'HandshakeException',
      );
      expect(describeErrorType(const TlsException('x')), 'TlsException');
      expect(describeErrorType(const SocketException('x')), 'SocketException');
      expect(describeErrorType(const HttpException('x')), 'HttpException');
      expect(describeErrorType(const OSError('x', 1)), 'OSError');
      expect(describeErrorType(StateError('x')), 'StateError');
    });

    test('rememberOriginalError : type conservé après remplacement', () {
      final err = DioException(
        requestOptions: RequestOptions(path: '/x'),
        error: const TlsException('boom'),
      );
      rememberOriginalError(err);
      final converted = err.copyWith(error: 'converti');
      expect(originalErrorTypeOf(converted), 'TlsException');
      expect(isCertificateFailure(converted), isFalse);
    });

    test('sans note : type de err.error', () {
      expect(
        originalErrorTypeOf(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            error: const SocketException('x'),
          ),
        ),
        'SocketException',
      );
    });

    test('isCertificateFailure : badCertificate et TLS « CERTIFICATE »', () {
      DioException err(DioExceptionType type, [Object? error]) => DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: type,
        error: error,
      );
      expect(
        isCertificateFailure(err(DioExceptionType.badCertificate)),
        isTrue,
      );
      expect(
        isCertificateFailure(
          err(
            DioExceptionType.unknown,
            const TlsException('x', OSError('CERTIFICATE_VERIFY_FAILED', 1)),
          ),
        ),
        isTrue,
      );
      expect(
        isCertificateFailure(
          err(DioExceptionType.unknown, const HandshakeException('terminated')),
        ),
        isFalse,
      );
      expect(isCertificateFailure(err(DioExceptionType.unknown)), isFalse);
      final options = RequestOptions(path: '/x');
      expect(
        isCertificateFailure(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badCertificate,
            response: Response(requestOptions: options, statusCode: 200),
          ),
        ),
        isFalse,
      );
    });

    test('une relance remplace la note de la tentative précédente', () {
      final options = RequestOptions(path: '/x');
      rememberOriginalError(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badCertificate,
        ),
      );
      final retry = DioException(
        requestOptions: options,
        error: const SocketException('x'),
      );
      rememberOriginalError(retry);
      expect(isCertificateFailure(retry), isFalse);
      expect(originalErrorTypeOf(retry), 'SocketException');
    });
  });
}
