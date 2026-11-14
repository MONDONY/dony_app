import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_catalog.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/trip_delay/trip_delay_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trip_delay_info.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:dony/features/matching/bloc/trip_delay/trip_delay_state.dart';

/// Annonce d'un retard sur le trajet [_trip], parti (`IN_PROGRESS`), tous
/// modes : nouvelle arrivée estimée (début et fin), motif, message facultatif.
/// Le serveur prévient chaque expéditeur dont le colis est à bord (push,
/// e-mail, message dans la conversation du colis).
///
/// Refus du serveur traduits par le catalogue d'erreurs : 409
/// `trip-delay-not-allowed` (trajet pas parti), 409 `trip-delay-too-frequent`
/// (plus de 5 retards en 24 h), 422 `arrival-range-invalid` (fin dans le
/// passé, début avant le départ, fin avant le début), 422 `arrival-too-far`
/// (au-delà de la durée maximale du mode), 422 `trip-delay-reason-invalid`
/// (congestion au port hors bateau).
class TripDelayCubit extends Cubit<TripDelayState> {
  TripDelayCubit(this._trip, this._repository, this._analytics)
    : super(const TripDelayInitial());

  final AnnouncementModel _trip;
  final AnnouncementRepository _repository;
  final AnalyticsService _analytics;

  /// Mode du trajet tel que mesuré (`transport_mode`) : la route regroupe la
  /// voiture et le bus, un mode absent (ancienne donnée) vaut avion.
  String get _mode =>
      transportModeOrPlane(_trip.transportMode).displayGroup.name;

  /// Un second envoi pendant le premier est ignoré (double appui) ; le
  /// serveur rend de toute façon le même retard sur un rejeu identique.
  Future<void> submit({
    required TripDelayReason reason,
    required DateTime arrivalDate,
    required DateTime arrivalDateMax,
    String? message,
  }) async {
    if (state is TripDelayLoading) return;
    emit(const TripDelayLoading());
    final text = message?.trim() ?? '';
    final reasonCode = reason.wire.toLowerCase();
    try {
      final delay = await _repository.announceDelay(
        announcementId: _trip.id,
        reason: reason,
        arrivalDate: arrivalDate,
        arrivalDateMax: arrivalDateMax,
        message: text.isEmpty ? null : text,
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.tripDelayAnnounced,
          properties: {
            'reason': reasonCode,
            'transport_mode': _mode,
            'range_days': _calendarDays(arrivalDate, arrivalDateMax),
            'has_message': text.isNotEmpty,
          },
        ),
      );
      if (!isClosed) emit(TripDelaySuccess(delay));
    } catch (e) {
      final error = unwrapDioError(e);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.tripDelayAnnounceFailed,
          properties: {
            'reason': reasonCode,
            'transport_mode': _mode,
            'error_code': error.code ?? 'unknown',
          },
        ),
      );
      if (!isClosed) {
        emit(
          TripDelayError(ErrorCatalog.lookup(error).message, code: error.code),
        );
      }
    }
  }

  /// Jours de calendrier entre le début et la fin de la fourchette.
  static int _calendarDays(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}
