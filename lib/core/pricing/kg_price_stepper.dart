import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/dony_pricing.dart';

/// Bornes et pas du sélecteur « − / + » du prix au kilo d'un trajet.
///
/// Mêmes bornes que le filtre de recherche ([priceFilterBoundsFor] : 3 à
/// 25 €/kg, pas de 1 en euro), sauf le plancher de la zone CFA : celui du
/// filtre (2 000 F CFA) écarterait les tarifs réellement pratiqués sur ces
/// routes (1 000 à 1 500 F CFA/kg, cf. [KgPriceReference.cfa]). Le plancher
/// descend donc jusqu'au premier repère de la devise, sans jamais passer sous
/// le minimum accepté par le serveur ([minUnitPriceFor]).
({double min, double max, double step}) kgPriceStepperBoundsFor(
  SupportedCurrency currency,
) {
  final filter = priceFilterBoundsFor(currency);
  final reference = KgPriceReference.forCurrency(currency);
  final step = filter.step;
  var min = filter.min < reference.presets.first
      ? filter.min
      : reference.presets.first;
  final serverMin = minUnitPriceFor(currency);
  if (min < serverMin) {
    min = (serverMin / step).ceil() * step;
  }
  final serverMax = maxUnitPriceFor(currency);
  final max = filter.max > serverMax ? serverMax : filter.max;
  return (min: min, max: max, step: step);
}

/// Ramène [price] dans les bornes du sélecteur.
double clampKgPrice(
  double price,
  ({double min, double max, double step}) bounds,
) {
  if (price < bounds.min) return bounds.min;
  if (price > bounds.max) return bounds.max;
  return price;
}

/// Prix suivant (ou précédent, [up] faux) d'un pas, borné.
///
/// Un prix hors grille (8,50 € conseillé, pas de 1) remonte d'abord au
/// multiple du pas le plus proche dans le sens demandé : 8,50 → 9 ou 8.
double stepKgPrice(
  double price,
  ({double min, double max, double step}) bounds, {
  required bool up,
}) {
  final step = bounds.step;
  final ratio = price / step;
  final onGrid = (ratio - ratio.round()).abs() < 1e-9;
  final double next;
  if (onGrid) {
    next = (ratio.round() + (up ? 1 : -1)) * step;
  } else {
    next = (up ? ratio.ceil() : ratio.floor()) * step;
  }
  return clampKgPrice(next, bounds);
}
