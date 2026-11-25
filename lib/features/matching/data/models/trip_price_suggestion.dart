import 'package:equatable/equatable.dart';

/// Prix pratiqué pour un article sur une route (médiane des grilles des
/// voyageurs qui publient sur ce trajet).
class TripPriceSuggestionItem extends Equatable {
  const TripPriceSuggestionItem({
    required this.label,
    required this.unitPrice,
    this.sampleSize = 0,
  });

  /// Libellé de l'article, tel que saisi dans les grilles (valeur de donnée).
  final String label;

  /// Prix unitaire net voyageur, dans la devise de la suggestion.
  final double unitPrice;

  /// Nombre de grilles qui portent cet article sur la route.
  final int sampleSize;

  /// Lecture tolérante : un élément incomplet est ignoré (`null`) plutôt que
  /// de faire échouer toute la réponse.
  static TripPriceSuggestionItem? tryParse(Object? json) {
    if (json is! Map) return null;
    final label = json['label'];
    final price = json['unitPrice'];
    if (label is! String || label.trim().isEmpty || price is! num) return null;
    if (price <= 0) return null;
    final sample = json['sampleSize'];
    return TripPriceSuggestionItem(
      label: label.trim(),
      unitPrice: price.toDouble(),
      sampleSize: sample is num ? sample.toInt() : 0,
    );
  }

  @override
  List<Object?> get props => [label, unitPrice, sampleSize];
}

/// Prix conseillés pour une route, calculés par le back
/// (`GET /announcements/price-suggestions`, yadony-back#788).
///
/// Les montants sont en unités de [currency]. [pricePerKg] est nul tant que
/// la route compte moins de trois trajets : l'app retombe alors sur sa
/// médiane embarquée (`KgPriceReference`).
class TripPriceSuggestion extends Equatable {
  const TripPriceSuggestion({
    required this.currency,
    this.pricePerKg,
    this.sampleSize = 0,
    this.items = const [],
  });

  final String currency;
  final double? pricePerKg;
  final int sampleSize;
  final List<TripPriceSuggestionItem> items;

  factory TripPriceSuggestion.fromJson(
    Map<String, dynamic> json, {
    required String requestedCurrency,
  }) {
    final currency = json['currency'];
    final price = json['pricePerKg'];
    final sample = json['sampleSize'];
    final rawItems = json['items'];
    return TripPriceSuggestion(
      currency: currency is String && currency.isNotEmpty
          ? currency.toUpperCase()
          : requestedCurrency,
      pricePerKg: price is num && price > 0 ? price.toDouble() : null,
      sampleSize: sample is num ? sample.toInt() : 0,
      items: rawItems is List
          ? [for (final raw in rawItems) ?TripPriceSuggestionItem.tryParse(raw)]
          : const [],
    );
  }

  @override
  List<Object?> get props => [currency, pricePerKg, sampleSize, items];
}
