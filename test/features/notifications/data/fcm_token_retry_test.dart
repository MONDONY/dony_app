import 'dart:async';

import 'package:dony/core/error/report_severity.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/features/notifications/data/fcm_token_retry.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';

/// Erreur relevée par Sentry (FLUTTER-N1).
FirebaseException _registrationFailed() => FirebaseException(
  plugin: 'firebase_messaging',
  code: 'unknown',
  message: 'java.io.IOException: FCM Registration failed!',
);

class _RecordingSink implements ErrorReportingSink {
  final errors = <Object>[];
  final contexts = <Map<String, Object>>[];

  @override
  Future<void> capture(
    Object error, {
    StackTrace? stackTrace,
    required Map<String, Object> context,
  }) async {
    errors.add(error);
    contexts.add(context);
  }
}

void main() {
  late _RecordingSink sink;
  late List<Duration> slept;
  late StreamController<bool> connectivity;
  late FcmTokenRetry retry;

  setUp(() {
    sink = _RecordingSink();
    slept = [];
    connectivity = StreamController<bool>.broadcast();
    retry = FcmTokenRetry(
      reporter: ErrorReportingService(sink),
      connectivityChanges: connectivity.stream,
      sleep: (d) async => slept.add(d),
    );
  });

  tearDown(() async {
    retry.dispose();
    await connectivity.close();
  });

  group('isTransientFcmTokenError', () {
    test('FCM Registration failed / SERVICE_NOT_AVAILABLE : passager', () {
      expect(isTransientFcmTokenError(_registrationFailed()), isTrue);
      expect(
        isTransientFcmTokenError(
          FirebaseException(
            plugin: 'firebase_messaging',
            code: 'unknown',
            message: 'SERVICE_NOT_AVAILABLE',
          ),
        ),
        isTrue,
      );
    });

    // FLUTTER-QB : sur iOS, `getToken` lève `[firebase_messaging/unknown]`
    // sans aucun marqueur Android dans le message.
    test('code unknown sans message (iOS) : passager', () {
      expect(
        isTransientFcmTokenError(
          FirebaseException(plugin: 'firebase_messaging', code: 'unknown'),
        ),
        isTrue,
      );
      expect(
        isTransientFcmTokenError(
          FirebaseException(
            plugin: 'firebase_messaging',
            code: 'unknown',
            message: 'The operation couldn’t be completed.',
          ),
        ),
        isTrue,
      );
    });

    test('code unknown iOS : réessayé par fetch', () async {
      var calls = 0;
      final token = await retry.fetch(() async {
        if (++calls < 2) {
          throw FirebaseException(
            plugin: 'firebase_messaging',
            code: 'unknown',
          );
        }
        return 'tok';
      });

      expect(token, 'tok');
      expect(calls, 2);
    });

    test('autres erreurs : pas passagères', () {
      expect(
        isTransientFcmTokenError(
          FirebaseException(
            plugin: 'firebase_messaging',
            code: 'apns-token-not-set',
          ),
        ),
        isFalse,
      );
      expect(
        isTransientFcmTokenError(
          FirebaseException(
            plugin: 'firebase_auth',
            code: 'unknown',
            message: 'IOException',
          ),
        ),
        isFalse,
      );
      expect(isTransientFcmTokenError(StateError('x')), isFalse);
    });
  });

  group('fetch', () {
    test('réussit après des échecs passagers, avec backoff', () async {
      var calls = 0;
      final token = await retry.fetch(() async {
        if (++calls < 3) throw _registrationFailed();
        return 'tok';
      });

      expect(token, 'tok');
      expect(calls, 3);
      expect(slept, FcmTokenRetry.defaultBackoff.take(2));
      expect(sink.errors, isEmpty);
    });

    test(
      'essais épuisés : l\'erreur passagère remonte, rien à Sentry',
      () async {
        var calls = 0;
        await expectLater(
          retry.fetch(() async {
            calls++;
            throw _registrationFailed();
          }),
          throwsA(isA<FirebaseException>()),
        );
        expect(calls, FcmTokenRetry.defaultBackoff.length + 1);
        expect(sink.errors, isEmpty);
      },
    );

    test('erreur non passagère : remonte au premier essai', () async {
      var calls = 0;
      await expectLater(
        retry.fetch(() async {
          calls++;
          throw StateError('boom');
        }),
        throwsStateError,
      );
      expect(calls, 1);
      expect(slept, isEmpty);
    });
  });

  test('reportExhausted : un seul avertissement par session', () async {
    retry.reportExhausted(_registrationFailed(), channel: 'fcm');
    retry.reportExhausted(_registrationFailed(), channel: 'stream_video');
    await Future<void>.delayed(Duration.zero);

    expect(sink.errors, hasLength(1));
    expect(sink.contexts.single['channel'], 'fcm');
    expect(
      sink.contexts.single['operation'],
      'notifications.fcm_token_unavailable_transient',
    );
    expect(sink.contexts.single['_level'], 'warning');
    expect(
      const FcmTokenRetriesExhausted().reportSeverity,
      ReportSeverity.warning,
    );
    expect(const FcmTokenRetriesExhausted().toString(), contains('Fcm'));
  });

  group('retryOpportunities', () {
    test('réseau retrouvé : une occasion ; réseau perdu : aucune', () async {
      final seen = <void>[];
      final sub = retry.retryOpportunities.listen(seen.add);
      addTearDown(sub.cancel);

      connectivity.add(false);
      connectivity.add(true);
      retry.notifyRetryOpportunity();
      await Future<void>.delayed(Duration.zero);

      expect(seen, hasLength(2));
    });

    test('sans effet une fois fermé', () {
      retry.dispose();
      expect(retry.notifyRetryOpportunity, returnsNormally);
    });
  });

  group('tokenStream (Stream Video)', () {
    test(
      'jeton initial puis rafraîchissements, sans jamais d\'erreur',
      () async {
        final refresh = StreamController<String>();
        final tokens = <String>[];
        final errors = <Object>[];
        final sub = retry
            .tokenStream(
              getToken: () async => 'tok-1',
              onTokenRefresh: () => refresh.stream,
            )
            .listen(tokens.add, onError: errors.add);
        addTearDown(sub.cancel);

        await Future<void>.delayed(Duration.zero);
        refresh.add('tok-2');
        refresh.addError(_registrationFailed());
        refresh.add('tok-3');
        await Future<void>.delayed(Duration.zero);

        expect(tokens, ['tok-1', 'tok-2', 'tok-3']);
        expect(errors, isEmpty);
        await refresh.close();
      },
    );

    test('FLUTTER-N1 : essais épuisés, aucun crash, avertissement unique, '
        'nouvel essai au retour du premier plan', () async {
      var failing = true;
      var calls = 0;
      final tokens = <String>[];
      final errors = <Object>[];
      final sub = retry
          .tokenStream(
            getToken: () async {
              calls++;
              if (failing) throw _registrationFailed();
              return 'tok';
            },
            onTokenRefresh: () => const Stream.empty(),
          )
          .listen(tokens.add, onError: errors.add);
      addTearDown(sub.cancel);

      await pumpEventQueue();
      expect(calls, FcmTokenRetry.defaultBackoff.length + 1);
      expect(tokens, isEmpty);
      expect(errors, isEmpty);
      expect(sink.errors, hasLength(1));
      expect(sink.contexts.single['channel'], 'stream_video');

      failing = false;
      retry.notifyRetryOpportunity();
      await pumpEventQueue();

      expect(tokens, ['tok']);
      expect(errors, isEmpty);
      expect(sink.errors, hasLength(1));
    });

    test('jeton vide : rien d\'émis', () async {
      final tokens = await retry
          .tokenStream(
            getToken: () async => '',
            onTokenRefresh: () => const Stream.empty(),
          )
          .toList();
      expect(tokens, isEmpty);
    });

    test('erreur non passagère : remontée, flux sans erreur', () async {
      final errors = <Object>[];
      final tokens = await retry
          .tokenStream(
            getToken: () async => throw StateError('boom'),
            onTokenRefresh: () => Stream.value('tok-2'),
          )
          .handleError(errors.add)
          .toList();
      await Future<void>.delayed(Duration.zero);

      expect(tokens, ['tok-2']);
      expect(errors, isEmpty);
      expect(sink.contexts.single['operation'], 'calls.push_token');
    });

    test('service fermé pendant l\'attente : le flux se termine', () async {
      final done = Completer<void>();
      retry
          .tokenStream(
            getToken: () async => throw _registrationFailed(),
            onTokenRefresh: () => Stream.value('jamais'),
          )
          .listen((_) {}, onDone: done.complete);
      await pumpEventQueue();

      retry.dispose();

      await done.future.timeout(const Duration(seconds: 1));
    });
  });
}
