import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/trip_price_suggestion.dart';

/// Prix conseillés d'une route (`GET /announcements/price-suggestions`,
/// yadony-back#788).
class PriceSuggestionRemoteDatasource {
  PriceSuggestionRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<TripPriceSuggestion> getSuggestions({
    required String departureCity,
    required String arrivalCity,
    required String currency,
  }) async {
    final response = await _apiClient.dio.get<Object?>(
      '/announcements/price-suggestions',
      queryParameters: {
        'departureCity': departureCity,
        'arrivalCity': arrivalCity,
        'currency': currency,
      },
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected Map from API'); // i18n-ignore
    }
    return TripPriceSuggestion.fromJson(data, requestedCurrency: currency);
  }
}
