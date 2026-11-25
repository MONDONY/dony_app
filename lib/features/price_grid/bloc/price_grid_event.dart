import 'package:dony/features/price_grid/data/models/price_grid_suggestion.dart';

abstract class PriceGridEvent {
  const PriceGridEvent();
}

class PriceGridLoadRequested extends PriceGridEvent {
  const PriceGridLoadRequested();
}

class PriceGridItemAddRequested extends PriceGridEvent {
  final String label;
  final double unitPriceNet;
  const PriceGridItemAddRequested({
    required this.label,
    required this.unitPriceNet,
  });
}

class PriceGridItemUpdateRequested extends PriceGridEvent {
  final String itemId;
  final String label;
  final double unitPriceNet;
  const PriceGridItemUpdateRequested({
    required this.itemId,
    required this.label,
    required this.unitPriceNet,
  });
}

class PriceGridItemDeleteRequested extends PriceGridEvent {
  final String itemId;
  const PriceGridItemDeleteRequested(this.itemId);
}

class PriceGridItemsReorderRequested extends PriceGridEvent {
  final List<String> orderedIds;
  const PriceGridItemsReorderRequested(this.orderedIds);
}

/// Ajoute d'un coup les prix pratiqués sur la route du trajet en cours de
/// publication, proposés quand la grille est vide.
class PriceGridSuggestionsAddRequested extends PriceGridEvent {
  final List<PriceGridSuggestion> suggestions;
  const PriceGridSuggestionsAddRequested(this.suggestions);
}
