import 'dart:io' show HttpException, SocketException;

import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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

  test('ignores rate limiting (RateLimitException and status 429)', () async {
    final sink = _RecordingSink();
    final reporter = ErrorReportingService(sink);

    await reporter.report(
      const RateLimitException(),
      operation: 'kyc.refresh_status',
    );
    expect(sink.error, isNull);

    await reporter.report(
      StateError('throttled'),
      operation: 'kyc.refresh_status',
      statusCode: 429,
    );
    expect(sink.error, isNull);
  });

  test(
    'ignores network conditions (OfflineException, TimeoutException)',
    () async {
      final sink = _RecordingSink();
      final reporter = ErrorReportingService(sink);

      await reporter.report(
        const OfflineException(),
        operation: 'kyc.create_session',
      );
      expect(sink.error, isNull);

      await reporter.report(
        const TimeoutException(),
        operation: 'kyc.create_session',
      );
      expect(sink.error, isNull);
    },
  );

  test(
    'keeps the closed FirebaseException code in the reported title',
    () async {
      final sink = _RecordingSink();
      final reporter = ErrorReportingService(sink);

      await reporter.report(
        FirebaseException(
          plugin: 'firebase_messaging',
          code: 'apns-token-not-set',
          message: 'APNS token has not been set yet for +2250102030405',
        ),
        operation: 'notifications.resolve_fcm_token',
      );

      expect(
        sink.error.toString(),
        'ReportedError(notifications.resolve_fcm_token, FirebaseException, '
        'apns-token-not-set)',
      );
      expect(sink.error.toString(), isNot(contains('+2250102030405')));
    },
  );

  test(
    'keeps the business code of an AppException wrapped in a DioException',
    () async {
      // L'intercepteur HTTP rapporte la DioException brute : sans dépliage, aucun
      // code métier n'atteignait Sentry et tout se regroupait sous une issue unique.
      final sink = _RecordingSink();
      final reporter = ErrorReportingService(sink);
      final options = RequestOptions(path: '/wallet/topup');

      await reporter.report(
        DioException(
          requestOptions: options,
          error: const ServerException('boom', 'wallet-topup-stripe-error'),
          response: Response(requestOptions: options, statusCode: 500),
        ),
        operation: 'http.POST',
      );

      expect(
        sink.error.toString(),
        'ReportedError(http.POST, DioException, wallet-topup-stripe-error)',
      );
    },
  );

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

  group('pannes transitoires et refus métier attendus', () {
    test('502/503/504 : empreinte http-transient-<statut>', () async {
      for (final status in [502, 503, 504]) {
        final sink = _RecordingSink();
        await ErrorReportingService(sink).report(
          const ServiceUnavailableException(),
          operation: 'http.GET',
          statusCode: status,
          context: const {'endpoint': '/api/v1/bids/1234'},
        );
        expect(
          sink.context![SentryErrorReportingSink.fingerprintKey],
          'http-transient-$status',
        );
        expect(sink.context!['endpoint'], '/api/v1/bids/:id');
      }
    });

    test('FLUTTER-M : upload du jeton FCM en 502 après ses essais', () async {
      final sink = _RecordingSink();
      await ErrorReportingService(sink).report(
        DioException(
          requestOptions: RequestOptions(path: '/notifications/token'),
          response: Response(
            requestOptions: RequestOptions(path: '/notifications/token'),
            statusCode: 502,
          ),
          error: const ServiceUnavailableException(),
        ),
        operation: 'notifications.upload_fcm_token',
        context: const {'attempts': 3},
      );
      expect(
        sink.context![SentryErrorReportingSink.fingerprintKey],
        'http-transient-502',
      );
    });

    test('API injoignable sans statut : http-transient-network', () {
      expect(
        ErrorReportingService.transientFingerprint(
          const ServiceUnavailableException(),
          null,
        ),
        'http-transient-network',
      );
      expect(
        ErrorReportingService.transientFingerprint(
          const ServerException('x'),
          500,
        ),
        isNull,
      );
    });

    group('connexion perdue sans réponse (FLUTTER-JQ)', () {
      final options = RequestOptions(
        path: '/api/v1/notifications/unread-count',
      );
      for (final (label, error) in [
        (
          'connectionError',
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        ),
        (
          'connectionTimeout',
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
          ),
        ),
        (
          'unknown + SocketException',
          DioException(
            requestOptions: options,
            error: const SocketException('Software caused connection abort'),
          ),
        ),
        (
          'unknown + HttpException',
          DioException(
            requestOptions: options,
            error: const HttpException('Connection closed'),
          ),
        ),
      ]) {
        test('$label : jamais rapporté', () async {
          final sink = _RecordingSink();
          await ErrorReportingService(
            sink,
          ).report(error, operation: 'http.GET');
          expect(sink.error, isNull);
        });
      }

      test('500 avec réponse : toujours rapporté', () async {
        final sink = _RecordingSink();
        await ErrorReportingService(sink).report(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: options, statusCode: 500),
            error: const ServerException('x'),
          ),
          operation: 'http.GET',
        );
        expect(sink.error, isNotNull);
        expect(sink.context!['status_code'], 500);
      });

      test('unknown sans erreur réseau : toujours rapporté', () async {
        final sink = _RecordingSink();
        await ErrorReportingService(sink).report(
          DioException(requestOptions: options, error: StateError('x')),
          operation: 'http.GET',
        );
        expect(sink.error, isNotNull);
      });
    });

    test('500 : pas d\'empreinte imposée', () async {
      final sink = _RecordingSink();
      await ErrorReportingService(sink).report(
        const ServerException('x'),
        operation: 'http.GET',
        statusCode: 500,
      );
      expect(
        sink.context!.containsKey(SentryErrorReportingSink.fingerprintKey),
        isFalse,
      );
    });

    for (final code in [
      'phone-otp-invalid',
      'phone-otp-expired',
      'otp-invalid',
      'otp-expired',
    ]) {
      test('400 $code : saisie de l\'utilisateur, jamais rapporté', () async {
        final sink = _RecordingSink();
        await ErrorReportingService(sink).report(
          DioException(
            requestOptions: RequestOptions(path: '/auth/phone/verify'),
            error: ValidationException('x', code: code),
          ),
          operation: 'http.POST',
          statusCode: 400,
        );
        expect(sink.error, isNull);
      });
    }

    test('un autre 400 reste rapporté', () async {
      final sink = _RecordingSink();
      await ErrorReportingService(sink).report(
        const ValidationException('x', code: 'validation'),
        operation: 'http.POST',
        statusCode: 400,
      );
      expect(sink.error, isNotNull);
    });

    test('applyReportContext : empreinte posée, absente du contexte', () async {
      final scope = Scope(SentryOptions());
      await SentryErrorReportingSink.applyReportContext(scope, {
        'operation': 'http.GET',
        'endpoint': '/api/v1/users/me',
        SentryErrorReportingSink.fingerprintKey: 'http-transient-503',
      });
      expect(scope.fingerprint, ['http-transient-503']);
      expect(scope.tags, containsPair('endpoint', '/api/v1/users/me'));
      final block = scope.contexts[SentryErrorReportingSink.contextKey] as Map;
      expect(
        block.containsKey(SentryErrorReportingSink.fingerprintKey),
        isFalse,
      );
    });
  });

  group('SentryErrorReportingSink (FLUTTER-CJ)', () {
    test(
      'applyReportContext met le contexte et les codes Stripe en tags',
      () async {
        final scope = Scope(SentryOptions());

        await SentryErrorReportingSink.applyReportContext(scope, {
          'operation': 'payments.init_sheet',
          'stripe_code': 'Failed',
          'decline_code': 'insufficient_funds',
          'stripe_error_type': 'card_error',
          'stripe_message': 'Your card was declined.',
          'status_code': 402,
        });

        final block = scope.contexts[SentryErrorReportingSink.contextKey];
        expect(block, isA<Map>());
        expect(
          block as Map,
          containsPair('stripe_message', 'Your card was declined.'),
        );
        expect(scope.tags, containsPair('operation', 'payments.init_sheet'));
        expect(scope.tags, containsPair('stripe_code', 'Failed'));
        expect(scope.tags, containsPair('decline_code', 'insufficient_funds'));
        expect(scope.tags, containsPair('stripe_error_type', 'card_error'));
        expect(scope.tags, containsPair('status_code', '402'));
        // Le message reste dans le contexte, jamais en tag.
        expect(scope.tags, isNot(contains('stripe_message')));
      },
    );

    test(
      "l'événement envoyé contient le contexte (pas seulement le hint)",
      () async {
        SentryEvent? sent;
        await Sentry.init((options) {
          options
            ..dsn = 'https://public@o0.ingest.sentry.io/0'
            ..beforeSend = (event, hint) {
              sent = event;
              return null; // rien ne part sur le réseau
            };
        });
        addTearDown(Sentry.close);

        await const SentryErrorReportingSink().capture(
          StateError('x'),
          context: const {
            'operation': 'payments.init_sheet',
            'stripe_code': 'Failed',
            'stripe_message': 'FragmentManager has been destroyed',
          },
        );

        expect(sent, isNotNull);
        expect(sent!.tags, containsPair('stripe_code', 'Failed'));
        expect(
          sent!.contexts[SentryErrorReportingSink.contextKey] as Map,
          containsPair('stripe_message', 'FragmentManager has been destroyed'),
        );
      },
    );
  });
}
