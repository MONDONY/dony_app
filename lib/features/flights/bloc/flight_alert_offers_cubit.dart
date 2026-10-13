import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/data/models/flight_alert_offers.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';
import 'package:dony/features/flights/data/repositories/flights_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum FlightAlertOffersStatus { loading, loaded, empty, error }

/// Ouverture de l'écran « Vols trouvés » : `list` depuis « Mes alertes »,
/// `notification` depuis une notification `FLIGHT_PRICE_ALERT`.
enum FlightAlertOffersSource {
  list,
  notification;

  static FlightAlertOffersSource parse(String? raw) =>
      raw == 'notification' ? notification : list;
}

/// Paramètres de l'écran « Vols trouvés » (GetIt `registerFactoryParam`).
class FlightAlertOffersArgs {
  const FlightAlertOffersArgs({
    required this.alertId,
    this.alert,
    this.source = FlightAlertOffersSource.list,
  });

  final String alertId;
  final FlightAlert? alert;
  final FlightAlertOffersSource source;
}

class FlightAlertOffersState extends Equatable {
  const FlightAlertOffersState({
    this.status = FlightAlertOffersStatus.loading,
    this.alert,
    this.result,
    this.error,
  });

  final FlightAlertOffersStatus status;

  /// L'alerte, quand elle est connue : passée par « Mes alertes », sinon
  /// retrouvée dans `GET /me/flight-alerts`. Donne la période du résumé et
  /// le repli Aviasales d'un ancien back.
  final FlightAlert? alert;
  final FlightAlertOffers? result;
  final AppException? error;

  /// Recherche Aviasales du trajet : celle du back, sinon reconstruite
  /// depuis l'alerte (ancien back sans la route des vols trouvés).
  String? searchPath(DateTime today) =>
      result?.searchPath ?? alert?.aviasalesSearchPath(today);

  /// Ce qu'ouvre « Plus de vols sur Aviasales » / « Rechercher en direct »,
  /// `null` sans chemin de recherche.
  FlightSearchResult? aviasalesTarget(DateTime today) {
    final path = searchPath(today);
    if (path == null) return null;
    final r = result;
    if (r != null) return r.toSearchResult(fallbackSearchPath: path);
    final a = alert!;
    return FlightSearchResult(
      originCode: a.originCode,
      destinationCode: a.destinationCode,
      roundTrip: a.isRoundTrip,
      currency: a.currency,
      offers: const [],
      searchPath: path,
    );
  }

  FlightAlertOffersState copyWith({
    FlightAlertOffersStatus? status,
    FlightAlert? alert,
    FlightAlertOffers? result,
    AppException? error,
  }) => FlightAlertOffersState(
    status: status ?? this.status,
    alert: alert ?? this.alert,
    result: result ?? this.result,
    error: error,
  );

  @override
  List<Object?> get props => [status, alert, result, error];
}

/// Vols trouvés par une alerte prix (`GET /me/flight-alerts/{id}/offers`).
///
/// Les prix sont relus à l'ouverture : un vol vu sous le seuil à la dernière
/// vérification peut avoir disparu, l'écran dit alors qu'il n'y a plus rien
/// sous le prix et propose Aviasales. Un back qui ne connaît pas encore la
/// route (404) mène au même état vide.
class FlightAlertOffersCubit extends Cubit<FlightAlertOffersState> {
  FlightAlertOffersCubit(
    this._repository,
    this._analytics, {
    required this.alertId,
    FlightAlert? alert,
    this.source = FlightAlertOffersSource.list,
  }) : super(FlightAlertOffersState(alert: alert));

  final FlightsRepository _repository;
  final AnalyticsService _analytics;
  final String alertId;
  final FlightAlertOffersSource source;

  bool _tracked = false;

  Future<void> load() async {
    emit(state.copyWith(status: FlightAlertOffersStatus.loading));
    final alertLookup = state.alert == null ? _findAlert() : null;
    try {
      final result = await _repository.alertOffers(alertId);
      final alert = alertLookup == null ? null : await alertLookup;
      if (isClosed) return;
      emit(
        state.copyWith(
          status: result.offers.isEmpty
              ? FlightAlertOffersStatus.empty
              : FlightAlertOffersStatus.loaded,
          result: result,
          alert: alert,
        ),
      );
      _trackViewed(result.offers.length);
    } catch (err) {
      final error = unwrapDioError(err);
      final alert = alertLookup == null ? null : await alertLookup;
      if (isClosed) return;
      if (error is NotFoundException) {
        // Alerte supprimée entre-temps, ou back sans la route : rien à
        // montrer sous le prix, Aviasales reste proposé si l'alerte est
        // connue.
        emit(
          state.copyWith(status: FlightAlertOffersStatus.empty, alert: alert),
        );
        _trackViewed(0);
        return;
      }
      emit(
        state.copyWith(
          status: FlightAlertOffersStatus.error,
          alert: alert,
          error: error,
        ),
      );
    }
  }

  /// L'alerte dans la liste du compte, sans jamais faire échouer l'écran.
  Future<FlightAlert?> _findAlert() async {
    try {
      final alerts = await _repository.alerts();
      return alerts.where((a) => a.id == alertId).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  /// Une fois par écran, au premier chargement abouti. Ni trajet ni prix.
  void _trackViewed(int count) {
    if (_tracked) return;
    _tracked = true;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.flightsAlertOffersViewed,
        properties: {'count': count, 'source': source.name},
      ),
    );
  }
}
