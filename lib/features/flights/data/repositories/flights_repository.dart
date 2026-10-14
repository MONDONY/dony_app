import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/flights/data/datasources/flights_remote_datasource.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/data/models/flight_alert_offers.dart';
import 'package:dony/features/flights/data/models/flight_deal.dart';
import 'package:dony/features/flights/data/models/flight_defaults.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_passengers.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';

/// Billets d'avion en affiliation : recherche, bons plans, alertes prix et
/// lien partenaire.
///
/// Les prix sont demandés dans la devise d'affichage de l'utilisateur
/// (Réglages › Devise d'affichage), à défaut dans sa devise active. Sans l'une
/// ni l'autre, le paramètre est omis et le back répond en euros.
class FlightsRepository {
  FlightsRepository(this._datasource, {String? Function()? currency})
    : _currency = currency ?? displayCurrencyFromHive;

  final FlightsRemoteDatasource _datasource;
  final String? Function() _currency;

  /// Devises que le back accepte pour les prix des vols.
  static const supportedCurrencies = {
    'EUR', 'XOF', 'XAF', 'USD', 'GBP', 'CAD', 'CHF', 'MAD', //
  };

  /// Devise d'affichage choisie (`'AUTO'` = suivre la devise active).
  static String? displayCurrencyFromHive() {
    String? display;
    try {
      final stored = getIt.isRegistered<HiveService>()
          ? getIt<HiveService>().userPrefs.get(HiveService.kDisplayCurrencyCode)
          : null;
      display = stored is String ? stored : null;
    } catch (_) {
      display = null;
    }
    final code = (display == null || display == 'AUTO')
        ? ActiveCurrency.current?.code
        : display;
    return code != null && supportedCurrencies.contains(code) ? code : null;
  }

  Future<FlightSearchResult> search(FlightSearchQuery query) =>
      _datasource.search(query, currency: _currency());

  Future<List<FlightPlace>> places(String term) => _datasource.places(term);

  Future<FlightDeals> deals() => _datasource.deals(currency: _currency());

  Future<FlightDefaults> defaults() => _datasource.defaults();

  Future<String> affiliateLink(
    FlightOffer offer, {
    required String source,
    FlightPassengers passengers = FlightPassengers.single,
  }) => _datasource.click(offer, source: source, passengers: passengers);

  Future<List<FlightAlert>> alerts() => _datasource.alerts();

  Future<FlightAlertOffers> alertOffers(String id) =>
      _datasource.alertOffers(id);

  Future<FlightAlert> createAlert(FlightAlertDraft draft) => _datasource
      .createAlert(draft.currency != null ? draft : _withCurrency(draft));

  Future<FlightAlert> setAlertActive(String id, bool active) =>
      _datasource.updateAlert(id, active: active);

  Future<void> deleteAlert(String id) => _datasource.deleteAlert(id);

  FlightAlertDraft _withCurrency(FlightAlertDraft d) => FlightAlertDraft(
    originCode: d.originCode,
    destinationCode: d.destinationCode,
    originLabel: d.originLabel,
    destinationLabel: d.destinationLabel,
    departureFrom: d.departureFrom,
    departureTo: d.departureTo,
    returnFrom: d.returnFrom,
    returnTo: d.returnTo,
    directOnly: d.directOnly,
    maxPrice: d.maxPrice,
    currency: _currency(),
  );
}
