import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/data/models/flight_deal.dart';
import 'package:dony/features/flights/data/models/flight_defaults.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';

/// Appels HTTP du package vols du back (`com.yadony.api.flights`).
class FlightsRemoteDatasource {
  FlightsRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<FlightSearchResult> search(
    FlightSearchQuery query, {
    String? currency,
  }) async {
    final res = await _apiClient.dio.get<Map<String, dynamic>>(
      '/flights/search',
      queryParameters: {
        'origin': query.origin!.code,
        'destination': query.destination!.code,
        if (query.departure != null)
          'departureDate': query.departure!.toQueryValue(),
        if (query.returnDate != null)
          'returnDate': query.returnDate!.toQueryValue(),
        'direct': query.directOnly,
        'currency': ?currency,
      },
    );
    return FlightSearchResult.fromJson(res.data!);
  }

  Future<List<FlightPlace>> places(String term) async {
    final res = await _apiClient.dio.get<List<dynamic>>(
      '/flights/places',
      queryParameters: {'term': term},
    );
    return (res.data ?? const [])
        .map((e) => FlightPlace.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FlightDeals> deals({String? currency}) async {
    final res = await _apiClient.dio.get<Map<String, dynamic>>(
      '/flights/deals',
      queryParameters: {'currency': ?currency},
    );
    return FlightDeals.fromJson(res.data!);
  }

  Future<FlightDefaults> defaults() async {
    final res = await _apiClient.dio.get<Map<String, dynamic>>(
      '/flights/defaults',
    );
    return FlightDefaults.fromJson(res.data!);
  }

  /// Enregistre le clic et renvoie le lien affilié complet à ouvrir.
  Future<String> click(FlightOffer offer, {required String source}) async {
    final res = await _apiClient.dio.post<Map<String, dynamic>>(
      '/flights/clicks',
      data: {
        'offerPath': offer.offerPath,
        'originCode': offer.originCode,
        'destinationCode': offer.destinationCode,
        'price': offer.price,
        'currency': offer.currency,
        'airlineCode': ?offer.airlineCode,
        'gate': ?offer.gate,
        'source': source,
      },
    );
    return res.data!['url'] as String;
  }

  Future<List<FlightAlert>> alerts() async {
    final res = await _apiClient.dio.get<List<dynamic>>('/me/flight-alerts');
    return (res.data ?? const [])
        .map((e) => FlightAlert.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FlightAlert> createAlert(FlightAlertDraft draft) async {
    final res = await _apiClient.dio.post<Map<String, dynamic>>(
      '/me/flight-alerts',
      data: draft.toJson(),
    );
    return FlightAlert.fromJson(res.data!);
  }

  Future<FlightAlert> updateAlert(
    String id, {
    bool? active,
    double? maxPrice,
  }) async {
    final res = await _apiClient.dio.patch<Map<String, dynamic>>(
      '/me/flight-alerts/$id',
      data: {'active': ?active, 'maxPrice': ?maxPrice},
    );
    return FlightAlert.fromJson(res.data!);
  }

  Future<void> deleteAlert(String id) =>
      _apiClient.dio.delete<void>('/me/flight-alerts/$id');
}
