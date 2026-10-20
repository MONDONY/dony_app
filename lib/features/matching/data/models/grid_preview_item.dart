import 'package:equatable/equatable.dart';

/// Représentation locale d'un article de grille de prix pour l'aperçu dans
/// le formulaire d'annonce.
///
/// Ce modèle est intentionnellement minimal et découplé de [PriceGridItemModel]
/// (feature price_grid). Le BLoC mappe [PriceGridItemModel] → [GridPreviewItem]
/// à la frontière des features pour respecter l'architecture feature-first.
class GridPreviewItem extends Equatable {
  final String id;
  final String label;
  final double unitPriceDisplay;

  /// Prix net saisi par le voyageur, ce qu'il touche. Sous grille de
  /// commission l'aperçu l'affiche tel quel (les frais de service s'ajoutent
  /// au total payé) ; `null` quand la source ne le fournit pas, l'aperçu garde
  /// alors [unitPriceDisplay].
  final double? unitPriceNet;

  const GridPreviewItem({
    required this.id,
    required this.label,
    required this.unitPriceDisplay,
    this.unitPriceNet,
  });

  @override
  List<Object?> get props => [id, label, unitPriceDisplay, unitPriceNet];
}
