import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;

/// Relit le nombre de notifications non lues et le reporte sur l'icône de
/// l'application, au seul retour au premier plan.
///
/// Jamais en partant vers l'arrière-plan (`inactive`, `hidden`, `paused`,
/// `detached`) : Android coupe alors les sockets de l'application, la requête
/// échouait sans réponse et remontait dans Sentry (FLUTTER-JQ, appareil
/// `paused` et hors ligne).
///
/// Une seule lecture à la fois : un appel pendant une lecture en cours la
/// rejoint. Et pas deux lectures à moins de [minInterval] : un va-et-vient
/// rapide (Face ID, centre de notifications) n'en relance pas une salve.
///
/// Silencieux en cas d'échec : une pastille périmée vaut mieux qu'une erreur
/// pour un compteur décoratif. La dernière valeur écrite reste affichée.
class NotificationBadgeSync {
  NotificationBadgeSync({
    required Future<int> Function() fetchUnreadCount,
    required Future<void> Function(int) applyBadge,
    this.minInterval = const Duration(seconds: 5),
    DateTime Function()? now,
  }) : _fetchUnreadCount = fetchUnreadCount,
       _applyBadge = applyBadge,
       _now = now ?? DateTime.now;

  final Future<int> Function() _fetchUnreadCount;
  final Future<void> Function(int) _applyBadge;
  final DateTime Function() _now;

  /// Délai minimal entre deux lectures (anti-rebond).
  final Duration minInterval;

  Future<void>? _inFlight;
  DateTime? _lastStartedAt;

  /// À appeler depuis `didChangeAppLifecycleState` : seul `resumed` lance une
  /// lecture.
  Future<void> onLifecycleChanged(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return Future.value();
    return sync();
  }

  /// Lance une lecture, sauf si une est en cours (on la rejoint) ou si la
  /// précédente a démarré il y a moins de [minInterval].
  Future<void> sync() {
    final running = _inFlight;
    if (running != null) return running;
    final now = _now();
    final last = _lastStartedAt;
    if (last != null && now.difference(last) < minInterval) {
      return Future.value();
    }
    _lastStartedAt = now;
    final future = _run().whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<void> _run() async {
    try {
      final unread = await _fetchUnreadCount();
      await _applyBadge(unread);
    } catch (_) {
      // Compteur indisponible (hors ligne, API injoignable) : on garde la
      // dernière valeur écrite.
    }
  }
}
