import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tracking/data/models/traveler_tracking_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Mesure de la carte « Suivi du voyageur » : affichage (une fois par
/// instance de carte) et ouverture de la frise. Aucune donnée affichée n'en
/// dépend, l'état dit seulement si l'affichage a déjà été compté.
class TravelerTrackingCardCubit extends Cubit<bool> {
  TravelerTrackingCardCubit({required AnalyticsService analytics})
    : _analytics = analytics,
      super(false);

  final AnalyticsService _analytics;

  /// Nom de la propriété `status` pour [status] (ni ville ni coordonnées).
  static String statusName(TravelerTrackingStatus status) => switch (status) {
    TravelerTrackingStatus.notActivated => 'not_activated',
    TravelerTrackingStatus.enRoute => 'en_route',
    TravelerTrackingStatus.arrived => 'arrived',
    TravelerTrackingStatus.stale => 'stale',
  };

  /// Compte l'affichage une seule fois, même si l'écran se reconstruit.
  void viewed(TravelerTrackingModel tracking) {
    if (state) return;
    emit(true);
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.travelerTrackingCardViewed,
        properties: {
          'status': statusName(tracking.status),
          'has_history': tracking.history.isNotEmpty,
        },
      ),
    );
  }

  void timelineOpened(TravelerTrackingModel tracking) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.travelerTrackingTimelineOpened,
        properties: {'status': statusName(tracking.status)},
      ),
    );
  }
}
