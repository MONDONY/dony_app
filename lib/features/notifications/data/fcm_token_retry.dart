import 'dart:async';

import 'package:dony/core/error/report_severity.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

/// Vrai pour un échec passager de Google Play Services à fabriquer le jeton
/// FCM (FLUTTER-N1 : `[firebase_messaging/unknown] java.io.IOException: FCM
/// Registration failed!`). Le même appel réussit quelques secondes ou un
/// lancement plus tard : ce n'est pas un défaut de l'app.
///
/// Sur iOS, le même échec passager arrive en `[firebase_messaging/unknown]`
/// sans aucun des marqueurs Android dans le message (FLUTTER-QB) : le code
/// `unknown` suffit donc à le classer passager.
bool isTransientFcmTokenError(Object error) {
  if (error is! FirebaseException) return false;
  if (error.plugin != 'firebase_messaging') return false;
  if (error.code == 'unknown') return true;
  final message = error.message ?? '';
  return _transientMarkers.any(message.contains);
}

const _transientMarkers = [
  'FCM Registration failed',
  'IOException',
  'SERVICE_NOT_AVAILABLE',
  'INTERNAL_SERVER_ERROR',
  'TIMEOUT',
];

/// Jeton FCM toujours indisponible après tous les essais de la session :
/// remonté une seule fois, en avertissement.
final class FcmTokenRetriesExhausted implements SeverityAwareError {
  const FcmTokenRetriesExhausted();

  @override
  ReportSeverity get reportSeverity => ReportSeverity.warning;

  @override
  String toString() => 'FcmTokenRetriesExhausted';
}

/// Lecture du jeton FCM tolérante aux échecs passagers (FLUTTER-N1), commune
/// à l'enregistrement Yadony (`NotificationService`) et à celui des appels
/// Stream Video.
///
/// - Un échec passager est réessayé après chaque délai de [backoff].
/// - Les essais épuisés, rien ne casse : l'appareil repart à la prochaine
///   occasion ([retryOpportunities] : retour au premier plan, réseau
///   retrouvé) ou au prochain lancement.
/// - Sentry n'en entend parler qu'une fois par session, en avertissement,
///   et seulement quand tous les essais ont échoué.
class FcmTokenRetry {
  FcmTokenRetry({
    ErrorReportingService? reporter,
    Stream<bool>? connectivityChanges,
    List<Duration> backoff = defaultBackoff,
    Future<void> Function(Duration)? sleep,
  }) : _reporter = reporter,
       _backoff = backoff,
       _sleep = sleep ?? Future<void>.delayed {
    _connectivitySub = connectivityChanges?.listen((online) {
      if (online) notifyRetryOpportunity();
    });
  }

  static const defaultBackoff = [
    Duration(seconds: 2),
    Duration(seconds: 8),
    Duration(seconds: 30),
  ];

  final ErrorReportingService? _reporter;
  final List<Duration> _backoff;
  final Future<void> Function(Duration) _sleep;
  final _opportunities = StreamController<void>.broadcast();
  StreamSubscription<bool>? _connectivitySub;
  bool _exhaustionReported = false;

  /// Moments où un nouvel essai a des chances d'aboutir.
  Stream<void> get retryOpportunities => _opportunities.stream;

  /// Retour au premier plan (app.dart) ou réseau retrouvé.
  void notifyRetryOpportunity() {
    if (!_opportunities.isClosed) _opportunities.add(null);
  }

  /// [getToken], réessayé sur échec passager. Les essais épuisés, l'erreur
  /// passagère remonte telle quelle : l'appelant appelle alors
  /// [reportExhausted]. Toute autre erreur remonte au premier essai.
  Future<String?> fetch(Future<String?> Function() getToken) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await getToken();
      } catch (error) {
        if (!isTransientFcmTokenError(error) || attempt >= _backoff.length) {
          rethrow;
        }
        await _sleep(_backoff[attempt]);
      }
    }
  }

  /// Signale, une seule fois par session, un jeton toujours indisponible
  /// après tous les essais. [channel] : `fcm` ou `stream_video`.
  void reportExhausted(Object error, {required String channel}) {
    AppLog.warn(
      'notifications.fcm_token_retries_exhausted',
      data: {'channel': channel, 'type': error.runtimeType.toString()},
    );
    if (_exhaustionReported) return;
    _exhaustionReported = true;
    unawaited(
      _reporter?.report(
        const FcmTokenRetriesExhausted(),
        operation: 'notifications.fcm_token_unavailable_transient',
        context: {
          'feature': 'notifications',
          'channel': channel,
          'attempts': _backoff.length + 1,
        },
      ),
    );
  }

  /// Flux de jetons pour le SDK Stream Video, qui l'écoute sans gérer ses
  /// erreurs : une erreur y devenait un crash non géré (FLUTTER-N1, niveau
  /// fatal). Ce flux n'émet jamais d'erreur. Le jeton initial est réessayé
  /// à chaque [retryOpportunities] tant qu'il manque ; les jetons suivants
  /// viennent de [onTokenRefresh].
  Stream<String> tokenStream({
    required Future<String?> Function() getToken,
    required Stream<String> Function() onTokenRefresh,
    String channel = 'stream_video',
  }) async* {
    for (;;) {
      try {
        final token = await fetch(getToken);
        if (token != null && token.isNotEmpty) yield token;
        break;
      } catch (error, stackTrace) {
        if (!isTransientFcmTokenError(error)) {
          unawaited(
            _reporter?.report(
              error,
              operation: 'calls.push_token',
              stackTrace: stackTrace,
              context: {'feature': 'calls', 'channel': channel},
            ),
          );
          break;
        }
        reportExhausted(error, channel: channel);
        try {
          await retryOpportunities.first;
        } on StateError {
          // Service fermé : plus d'occasion dans cette session.
          return;
        }
      }
    }
    yield* onTokenRefresh().transform(
      StreamTransformer<String, String>.fromHandlers(
        handleError: (error, _, _) => AppLog.warn(
          'notifications.fcm_token_refresh_failed',
          data: {'channel': channel, 'type': error.runtimeType.toString()},
        ),
      ),
    );
  }

  void dispose() {
    unawaited(_connectivitySub?.cancel());
    unawaited(_opportunities.close());
  }
}
