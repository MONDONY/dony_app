import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingSink implements ErrorReportingSink {
  Object? error;
  StackTrace? stackTrace;
  Map<String, Object>? context;

  @override
  Future<void> capture(
    Object error, {
    StackTrace? stackTrace,
    required Map<String, Object> context,
  }) async {
    this.error = error;
    this.stackTrace = stackTrace;
    this.context = context;
  }
}

void main() {
  test('ignores expected API errors', () async {
    final sink = _RecordingSink();
    final reporter = ErrorReportingService(sink);

    await reporter.report(
      const UnauthorizedException('phone=+2250102030405'),
      operation: 'auth.profile',
      statusCode: 401,
    );

    expect(sink.error, isNull);
  });

  test('captures critical errors with safe context only', () async {
    final sink = _RecordingSink();
    final reporter = ErrorReportingService(sink);

    await reporter.report(
      StateError('secret=client_secret_phone=+2250102030405'),
      operation: 'payment.confirm',
      context: {'method': 'card', 'endpoint': '/payments/confirm/123'},
      stackTrace: StackTrace.current,
    );

    expect(sink.error.toString(), isNot(contains('client_secret')));
    expect(sink.error.toString(), isNot(contains('+225')));
    expect(sink.context, {
      'operation': 'payment.confirm',
      'error_type': 'StateError',
      'endpoint': '/payments/confirm/:id',
      'method': 'card',
    });
    expect(sink.stackTrace, isNotNull);
  });

  test(
    'preserves safe APNs diagnostics used to investigate token failures',
    () async {
      final sink = _RecordingSink();
      final reporter = ErrorReportingService(sink);

      await reporter.report(
        StateError('FCM token unavailable'),
        operation: 'notifications.fcm_token_unavailable',
        context: {
          'feature': 'notifications',
          'channel': 'fcm',
          'apns_token_available': false,
          'platform': 'ios',
          'attempts': 3,
          'device_token': 'must-not-leak',
        },
      );

      expect(sink.context, containsPair('apns_token_available', false));
      expect(sink.context, containsPair('platform', 'ios'));
      expect(sink.context, containsPair('attempts', 3));
      expect(sink.context, isNot(contains('device_token')));
    },
  );

  test('captures server errors but not validation errors', () async {
    final sink = _RecordingSink();
    final reporter = ErrorReportingService(sink);

    await reporter.report(
      const NetworkException('backend detail'),
      operation: 'profile.load',
      statusCode: 500,
    );
    expect(sink.error, isNotNull);

    sink.error = null;
    await reporter.report(
      const ValidationException('invalid address'),
      operation: 'profile.save',
      statusCode: 422,
    );
    expect(sink.error, isNull);
  });
}
