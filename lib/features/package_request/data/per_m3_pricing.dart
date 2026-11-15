import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/package_request/data/per_kilo_pricing.dart';

/// Prix au m³ d'une demande en bateau : pur calcul de présentation.
///
/// Comme le prix au kilo ([PerKiloPricing]), c'est une aide de saisie : le back
/// ne connaît que le total (`totalBudget`). L'app calcule `volume × prix au
/// m³`, l'arrondit à la précision de la devise et n'envoie que ce total.
abstract final class PerM3Pricing {
  /// Le prix au m³ n'a de sens que si le volume du colis est connu.
  static bool isAvailable(double? volumeM3) => volumeM3 != null && volumeM3 > 0;

  /// Total d'un colis de [volumeM3] au prix de [perM3] par m³, arrondi à la
  /// plus petite unité de [currency]. `null` si le volume ou le prix manque, ou
  /// n'est pas positif.
  static double? totalFor({
    required double? volumeM3,
    required double? perM3,
    required SupportedCurrency currency,
  }) {
    if (!isAvailable(volumeM3) || perM3 == null || perM3 <= 0) return null;
    return PerKiloPricing.roundTo(volumeM3! * perM3, currency.minorUnit);
  }

  /// Prix au m³ qui redonne EXACTEMENT [total] pour [volumeM3], à deux
  /// décimales ; `null` si aucun ne le redonne (le total n'est alors pas
  /// changé en silence).
  static double? perM3For({
    required double? total,
    required double? volumeM3,
    required SupportedCurrency currency,
  }) {
    if (!isAvailable(volumeM3) || total == null || total <= 0) return null;
    final candidate = PerKiloPricing.roundTo(total / volumeM3!, 2);
    final back = totalFor(
      volumeM3: volumeM3,
      perM3: candidate,
      currency: currency,
    );
    return back == total ? candidate : null;
  }
}
