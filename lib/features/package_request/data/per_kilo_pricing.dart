import 'package:dony/core/currency/supported_currency.dart';

/// Prix au kilo d'une demande : pur calcul de présentation.
///
/// L'expéditeur peut saisir un prix au kilo plutôt qu'un total. Le back ne
/// connaît que le total (`totalBudget`) : l'app calcule `poids × prix au kilo`,
/// l'arrondit à la précision de la devise, et envoie CE total, comme avant.
/// Aucun champ n'est ajouté au contrat.
abstract final class PerKiloPricing {
  /// Le prix au kilo n'a de sens que si le poids du colis est connu.
  static bool isAvailable(double? weightKg) => weightKg != null && weightKg > 0;

  /// Total d'un colis de [weightKg] au prix de [perKilo] par kilo, arrondi à
  /// la plus petite unité de [currency] (centime, ou franc en CFA).
  /// `null` si le poids ou le prix au kilo manque, ou n'est pas positif.
  static double? totalFor({
    required double? weightKg,
    required double? perKilo,
    required SupportedCurrency currency,
  }) {
    if (!isAvailable(weightKg) || perKilo == null || perKilo <= 0) return null;
    return _roundTo(weightKg! * perKilo, currency.minorUnit);
  }

  /// Prix au kilo qui redonne EXACTEMENT [total] pour [weightKg], arrondi à
  /// deux décimales ; `null` si aucun prix au kilo à deux décimales ne le
  /// redonne (on ne change alors pas silencieusement le total).
  static double? perKiloFor({
    required double? total,
    required double? weightKg,
    required SupportedCurrency currency,
  }) {
    if (!isAvailable(weightKg) || total == null || total <= 0) return null;
    final candidate = _roundTo(total / weightKg!, 2);
    final back = totalFor(
      weightKg: weightKg,
      perKilo: candidate,
      currency: currency,
    );
    return back == total ? candidate : null;
  }

  static double _roundTo(double value, int decimals) {
    var factor = 1.0;
    for (var i = 0; i < decimals; i++) {
      factor *= 10;
    }
    // toStringAsFixed gomme le bruit binaire (3 × 3,335 = 10,004999…) : un
    // demi-centime exact s'arrondit vers le haut, comme à la main.
    final scaled = double.parse((value * factor).toStringAsFixed(6));
    return scaled.round() / factor;
  }
}
