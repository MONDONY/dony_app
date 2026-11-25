import 'package:equatable/equatable.dart';

/// Article proposé pour remplir une grille vide : prix pratiqué sur la route
/// du trajet en cours de publication, déjà exprimé dans la devise de la grille.
class PriceGridSuggestion extends Equatable {
  const PriceGridSuggestion({required this.label, required this.unitPriceNet});

  final String label;

  /// Ce que le voyageur touche pour cet article.
  final double unitPriceNet;

  @override
  List<Object?> get props => [label, unitPriceNet];
}
