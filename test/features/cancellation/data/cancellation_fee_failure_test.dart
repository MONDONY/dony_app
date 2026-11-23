import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/cancellation/data/cancellation_fee_failure.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dio(AppException error) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: DioExceptionType.badResponse,
  error: error,
);

void main() {
  group('cancellationFeeFailureCode', () {
    test('404 (back antérieur à la route) : rien à signaler', () {
      expect(
        cancellationFeeFailureCode(_dio(const NotFoundException())),
        isNull,
      );
      expect(cancellationFeeFailureCode(const NotFoundException()), isNull);
    });

    test('corps illisible : invalid_payload', () {
      expect(
        cancellationFeeFailureCode(const FormatException('x')),
        'invalid_payload',
      );
      expect(cancellationFeeFailureCode(TypeError()), 'invalid_payload');
    });

    test('délai dépassé : le code de l\'erreur', () {
      expect(cancellationFeeFailureCode(const TimeoutException()), 'TIMEOUT');
    });

    test('autre erreur : son code, unknown sans code', () {
      expect(
        cancellationFeeFailureCode(const ForbiddenException()),
        'FORBIDDEN',
      );
      expect(
        cancellationFeeFailureCode(const NetworkException('x')),
        'unknown',
      );
    });
  });
}
