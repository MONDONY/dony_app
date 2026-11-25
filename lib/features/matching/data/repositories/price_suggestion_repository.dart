import 'package:dony/features/matching/data/datasources/price_suggestion_remote_datasource.dart';
import 'package:dony/features/matching/data/models/trip_price_suggestion.dart';

/// Prix conseillés d'une route, tolérants à un back qui ne les connaît pas.
///
/// La route arrive avec yadony-back#788 : tant qu'elle n'est pas déployée, le
/// back répond 404. Ce cas, comme une erreur réseau ou une réponse illisible,
/// rend `null` : l'écran retombe sur sa médiane embarquée sans rien afficher
/// d'anormal. Les prix ne sont qu'une aide, jamais un blocage.
class PriceSuggestionRepository {
  PriceSuggestionRepository(this._datasource);

  final PriceSuggestionRemoteDatasource _datasource;

  Future<TripPriceSuggestion?> getSuggestions({
    required String departureCity,
    required String arrivalCity,
    required String currency,
  }) async {
    try {
      return await _datasource.getSuggestions(
        departureCity: departureCity,
        arrivalCity: arrivalCity,
        currency: currency,
      );
    } on Object {
      return null;
    }
  }
}
