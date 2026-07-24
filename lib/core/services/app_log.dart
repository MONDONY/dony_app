import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Journalisation applicative unifiée.
///
/// Un seul point d'entrée pour tous les logs de l'app :
/// - en debug → écrit dans la console (`debugPrint`) ;
/// - en tout mode → pousse vers Sentry (Logs structurés + breadcrumb de piste).
///
/// Sentry reste **no-op tant que `SENTRY_DSN` est absent** (init non effectuée
/// dans `main()`), donc appeler [AppLog] sans backend Sentry ne coûte rien et
/// ne lève jamais.
///
/// **Jamais de PII** dans `message`/`attributes` (téléphone, email, token,
/// données KYC) — mêmes règles que l'analytics.
abstract final class AppLog {
  static void debug(String message, {Map<String, Object>? data}) {
    _console('DEBUG', message, data);
    unawaited(Future.sync(() => Sentry.logger.debug(message, attributes: _attrs(data))));
    _breadcrumb(message, data, SentryLevel.debug);
  }

  static void info(String message, {Map<String, Object>? data}) {
    _console('INFO', message, data);
    unawaited(Future.sync(() => Sentry.logger.info(message, attributes: _attrs(data))));
    _breadcrumb(message, data, SentryLevel.info);
  }

  static void warn(String message, {Map<String, Object>? data}) {
    _console('WARN', message, data);
    unawaited(Future.sync(() => Sentry.logger.warn(message, attributes: _attrs(data))));
    _breadcrumb(message, data, SentryLevel.warning);
  }

  /// Erreur applicative. En plus du log/breadcrumb, si [error] est fourni la
  /// stacktrace est capturée comme événement Sentry (issue) via
  /// [Sentry.captureException].
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object>? data,
  }) {
    _console('ERROR', '$message${error != null ? ' — $error' : ''}', data);
    unawaited(Future.sync(() => Sentry.logger.error(message, attributes: _attrs(data))));
    _breadcrumb(message, data, SentryLevel.error);
    if (error != null) {
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
    }
  }

  static void _console(String level, String message, Map<String, Object>? data) {
    if (!kDebugMode) return;
    final suffix = (data == null || data.isEmpty) ? '' : ' $data';
    debugPrint('[dony] $level $message$suffix');
  }

  /// Ajoute un breadcrumb Sentry — la « piste » d'événements qui accompagne le
  /// prochain crash. Complète les Logs structurés (visibles même sans crash).
  static void _breadcrumb(String message, Map<String, Object>? data, SentryLevel level) {
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: message,
          level: level,
          data: data,
          category: 'app',
        ),
      ),
    );
  }

  static Map<String, SentryAttribute>? _attrs(Map<String, Object>? data) {
    if (data == null || data.isEmpty) return null;
    return data.map((key, value) => MapEntry(key, _toAttribute(value)));
  }

  static SentryAttribute _toAttribute(Object value) {
    if (value is int) return SentryAttribute.int(value);
    if (value is double) return SentryAttribute.double(value);
    if (value is bool) return SentryAttribute.bool(value);
    return SentryAttribute.string(value.toString());
  }
}
