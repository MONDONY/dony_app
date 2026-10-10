import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/retry_policy.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RetryPolicy.isReplayable', () {
    test('méthodes sûres : rejouables', () {
      for (final m in ['GET', 'get', 'HEAD', 'OPTIONS']) {
        expect(RetryPolicy.isReplayable(RequestOptions(method: m)), isTrue);
      }
    });

    test('écritures sans clé : jamais rejouées', () {
      for (final m in ['POST', 'PUT', 'PATCH', 'DELETE']) {
        expect(RetryPolicy.isReplayable(RequestOptions(method: m)), isFalse);
      }
    });

    test('écriture avec clé d\'idempotence (casse libre) : rejouable', () {
      expect(
        RetryPolicy.isReplayable(
          RequestOptions(method: 'POST', headers: {'idempotency-key': 'k'}),
        ),
        isTrue,
      );
      expect(
        RetryPolicy.isReplayable(
          RequestOptions(method: 'POST', headers: {'Idempotency-Key': ' '}),
        ),
        isFalse,
      );
    });

    test('multipart : jamais rejoué, même en GET', () {
      expect(
        RetryPolicy.isReplayable(
          RequestOptions(method: 'GET', data: FormData()),
        ),
        isFalse,
      );
    });
  });

  test('retryCountOf additionne tous les motifs', () {
    final options = RequestOptions(
      extra: {
        RetryPolicy.rateLimitAttemptKey: 1,
        RetryPolicy.transientAttemptKey: 2,
        RetryPolicy.authRefreshedKey: true,
      },
    );
    expect(RetryPolicy.retryCountOf(options), 4);
    expect(RetryPolicy.retryCountOf(RequestOptions()), 0);
  });

  group('ErrorReportingService', () {
    test('normalizeEndpoint masque jetons et numéros', () {
      expect(
        ErrorReportingService.normalizeEndpoint(
          '/tracking/ab12cd34ef56gh78ij90kl/events',
        ),
        '/tracking/:token/events',
      );
      expect(
        ErrorReportingService.normalizeEndpoint('/users/+33612345678'),
        '/users/:id',
      );
      expect(
        ErrorReportingService.normalizeEndpoint(
          '/bids/recipient-replacement-request',
        ),
        '/bids/recipient-replacement-request',
      );
    });
  });

  test('TIMEOUT dans une DioException : attendu, jamais rapporté', () async {
    final captured = <Object>[];
    final service = ErrorReportingService(_Sink(captured));
    await service.report(
      DioException(
        requestOptions: RequestOptions(),
        error: const TimeoutException(),
      ),
      operation: 'http.GET',
    );
    await service.report(
      DioException(
        requestOptions: RequestOptions(),
        error: const ServiceUnavailableException(),
      ),
      operation: 'http.GET',
    );
    expect(captured, hasLength(1));
  });
}

class _Sink implements ErrorReportingSink {
  _Sink(this.captured);

  final List<Object> captured;

  @override
  Future<void> capture(
    Object error, {
    StackTrace? stackTrace,
    required Map<String, Object> context,
  }) async => captured.add(error);
}
