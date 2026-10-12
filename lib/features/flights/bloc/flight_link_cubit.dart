import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';
import 'package:dony/features/flights/data/repositories/flights_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FlightLinkState extends Equatable {
  const FlightLinkState({this.openingPath, this.error, this.failures = 0});

  /// `offerPath` de l'offre en cours d'ouverture (son bouton tourne).
  final String? openingPath;
  final AppException? error;

  /// Compteur d'échecs : change à chaque échec, même identique, pour que
  /// l'écran réaffiche le message.
  final int failures;

  @override
  List<Object?> get props => [openingPath, error, failures];
}

/// « Voir l'offre » : demande le lien affilié au back (`POST /flights/clicks`,
/// qui enregistre le clic), puis l'ouvre dans le navigateur externe, jamais en
/// webview (le site partenaire encaisse le paiement).
class FlightLinkCubit extends Cubit<FlightLinkState> {
  FlightLinkCubit(this._repository, this._analytics, this._launcher)
    : super(const FlightLinkState());

  final FlightsRepository _repository;
  final AnalyticsService _analytics;
  final ExternalUrlLauncher _launcher;

  /// « Voir toutes les compagnies sur Aviasales » : la recherche complète du
  /// trajet ([FlightSearchResult.searchPath]) passe par le même endpoint que
  /// les offres, qui la transforme en lien affilié. [from] : `results`
  /// (encart de la liste) ou `empty` (écran « Aucun vol »).
  Future<void> openAllAirlines(
    FlightSearchResult result, {
    required String from,
  }) async {
    final path = result.searchPath;
    if (path == null) return;
    return open(
      FlightOffer(
        originCode: result.originCode,
        destinationCode: result.destinationCode,
        price: 0,
        currency: result.currency,
        offerPath: path,
      ),
      source: 'search',
      allAirlinesFrom: from,
    );
  }

  /// [source] : `search`, `deal` ou `alert` (contrat du back).
  Future<void> open(
    FlightOffer offer, {
    required String source,
    String? allAirlinesFrom,
  }) async {
    if (state.openingPath != null) return;
    emit(
      FlightLinkState(openingPath: offer.offerPath, failures: state.failures),
    );
    String reason;
    try {
      final url = await _repository.affiliateLink(offer, source: source);
      final uri = Uri.tryParse(url);
      final opened = uri != null && await _launcher.open(uri);
      if (opened) {
        if (!isClosed) emit(FlightLinkState(failures: state.failures));
        if (allAirlinesFrom != null) {
          unawaited(
            _analytics.logEvent(
              AnalyticsEvents.flightsAllAirlinesOpened,
              properties: {'from': allAirlinesFrom},
            ),
          );
          return;
        }
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.flightsOfferClicked,
            properties: {
              'source': source,
              'airline_code': ?offer.airlineCode,
              'stops': offer.transfers ?? -1,
              'round_trip': offer.isRoundTrip,
            },
          ),
        );
        return;
      }
      reason = 'launch';
    } catch (err) {
      final error = unwrapDioError(err);
      reason = error.code ?? 'unknown';
      if (!isClosed) {
        emit(FlightLinkState(error: error, failures: state.failures + 1));
      }
      unawaited(_logFailure(reason));
      return;
    }
    if (!isClosed) {
      emit(
        FlightLinkState(
          error: const NetworkException(
            'launch',
            code: 'flights-launch-failed',
          ), // i18n-ignore
          failures: state.failures + 1,
        ),
      );
    }
    unawaited(_logFailure(reason));
  }

  Future<void> _logFailure(String reason) => _analytics.logEvent(
    AnalyticsEvents.flightsOfferOpenFailed,
    properties: {'reason': reason},
  );
}
