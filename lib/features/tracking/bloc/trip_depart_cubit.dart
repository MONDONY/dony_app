import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/tracking/bloc/tracking_consent_cubit.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:dony/features/tracking/data/trip_tracking_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TripDepartState extends Equatable {
  const TripDepartState({
    this.departed = false,
    this.loading = false,
    this.error,
  });

  /// « Je pars » déjà confirmé depuis cet appareil (drapeau local par trajet).
  final bool departed;
  final bool loading;

  /// Dernière erreur, à montrer une fois ; remise à `null` au prochain essai.
  final AppException? error;

  @override
  List<Object?> get props => [departed, loading, error];
}

/// Bouton « Je pars » du trajet : demande le consentement (sans jamais
/// bloquer), joint la position approximative si elle est déjà autorisée,
/// puis prévient le back. Le refus de la localisation ne retient rien.
class TripDepartCubit extends Cubit<TripDepartState> {
  TripDepartCubit({
    required this.announcementId,
    required TripTrackingRepository tracking,
    required ScanLocator locator,
    required TrackingConsentCubit consent,
    required AnalyticsService analytics,
    required Box<dynamic> Function() box,
  }) : _tracking = tracking,
       _locator = locator,
       _consent = consent,
       _analytics = analytics,
       _box = box,
       super(const TripDepartState()) {
    emit(TripDepartState(departed: _storedDeparted()));
  }

  final String announcementId;
  final TripTrackingRepository _tracking;
  final ScanLocator _locator;
  final TrackingConsentCubit _consent;
  final AnalyticsService _analytics;
  final Box<dynamic> Function() _box;

  String get _key => '${HiveService.kTripDepartedPrefix}$announcementId';

  bool _storedDeparted() {
    try {
      return _box().get(_key) == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> depart(BuildContext context) async {
    if (state.loading || state.departed) return;
    emit(const TripDepartState(loading: true));
    var allowed = false;
    try {
      allowed = await _consent.ensureAsked(
        context,
        source: TrackingConsentSource.depart,
      );
    } catch (_) {
      // La réponse au consentement ne bloque jamais le départ.
    }
    // Sans consentement actif, le départ part sans position.
    ScanPosition? position;
    if (allowed) {
      try {
        position = await quickPositionIfGranted(_locator);
      } catch (_) {
        position = null;
      }
    }
    try {
      await _tracking.depart(
        announcementId,
        lat: position?.lat,
        lon: position?.lon,
      );
      try {
        await _box().put(_key, true);
      } catch (_) {
        // Drapeau de confort : au pire le bouton reste affiché.
      }
      emit(const TripDepartState(departed: true));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.tripDepartureConfirmed,
          properties: {'has_position': position != null},
        ),
      );
    } catch (e) {
      emit(TripDepartState(error: unwrapDioError(e)));
    }
  }
}
