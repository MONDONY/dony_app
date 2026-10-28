import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:dony/features/tracking/data/trip_tracking_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Le cubit n'a rien à montrer : il ne fait qu'envoyer en silence.
enum PositionReporterState { idle }

/// Envoie la position approximative du voyageur au back quand l'app revient
/// au premier plan, tant qu'un de ses trajets a sa fenêtre de suivi ouverte.
///
/// Silencieux de bout en bout : jamais de demande de permission, jamais
/// d'erreur affichée, aucune coordonnée journalisée ni envoyée à l'analytics.
class PositionReporterCubit extends Cubit<PositionReporterState> {
  PositionReporterCubit({
    required AnnouncementRepository announcements,
    required TripTrackingRepository tracking,
    required ScanLocator locator,
    required AnalyticsService analytics,
    required bool Function() hasRealSession,
    DateTime Function()? now,
  }) : _announcements = announcements,
       _tracking = tracking,
       _locator = locator,
       _analytics = analytics,
       _hasRealSession = hasRealSession,
       _now = now ?? DateTime.now,
       super(PositionReporterState.idle);

  /// Délai minimal entre deux essais (en mémoire, rien de persisté).
  static const throttle = Duration(minutes: 15);

  /// Nombre maximal de trajets renseignés par reprise.
  static const maxTrips = 3;

  final AnnouncementRepository _announcements;
  final TripTrackingRepository _tracking;
  final ScanLocator _locator;
  final AnalyticsService _analytics;
  final bool Function() _hasRealSession;
  final DateTime Function() _now;

  DateTime? _lastAttempt;
  bool _running = false;

  /// À appeler à la reprise de l'app et au démarrage à froid.
  Future<void> onResume() async {
    if (_running) return;
    _running = true;
    try {
      await _run();
    } catch (e) {
      // Jamais de coordonnées dans le message : seulement le type d'erreur.
      AppLog.debug(
        'position_reporter_failed',
        data: {'error': '${e.runtimeType}'},
      );
    } finally {
      _running = false;
    }
  }

  Future<void> _run() async {
    if (!_hasRealSession()) return _skip('no_session');
    final now = _now();
    final last = _lastAttempt;
    if (last != null && now.difference(last) < throttle) {
      return _skip('throttled');
    }
    _lastAttempt = now;

    final result = await _announcements.getMyAnnouncements();
    final active = result.announcements
        .where((a) => a.trackingActive)
        .take(maxTrips)
        .toList();
    if (active.isEmpty) return _skip('no_active_trip');

    if (!await _locator.isPermissionGranted()) return _skip('no_permission');
    final position = await _locator.captureCoordinatesIfGranted();
    if (position == null) return _skip('no_position');

    var sent = false;
    for (final trip in active) {
      try {
        await _tracking.sendPosition(trip.id, position.lat, position.lon);
        sent = true;
      } catch (e) {
        AppLog.debug(
          'position_send_failed',
          data: {'error': '${e.runtimeType}'},
        );
      }
    }
    if (sent) {
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.tripPositionSent,
          properties: const {'source': 'resume'},
        ),
      );
    }
  }

  void _skip(String reason) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tripPositionSkipped,
        properties: {'reason': reason},
      ),
    );
  }
}
