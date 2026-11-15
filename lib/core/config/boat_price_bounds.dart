import 'dart:math' as math;

import 'package:dony/core/currency/supported_currency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Bornes du prix au m³ d'un trajet bateau, en euros
/// (`GET /config/boat-price-bounds`, réglables depuis le back-office).
///
/// - Hors de [hardMinEur]..[hardMaxEur] : le serveur refuse le trajet (422
///   `price-per-m3-out-of-bounds`), le formulaire bloque la publication.
/// - Hors de [advisedMinEur]..[advisedMaxEur] : simple avertissement.
/// - [referenceEur] : prix habituel affiché sous le champ.
///
/// Repli sûr : [defaults], les valeurs du serveur à sa mise en service. Un
/// serveur sans la route (404) ou une erreur réseau ne bloquent jamais la
/// création d'un trajet.
@immutable
class BoatPriceBounds extends Equatable {
  final double hardMinEur;
  final double hardMaxEur;
  final double advisedMinEur;
  final double advisedMaxEur;
  final double referenceEur;

  const BoatPriceBounds({
    required this.hardMinEur,
    required this.hardMaxEur,
    required this.advisedMinEur,
    required this.advisedMaxEur,
    required this.referenceEur,
  });

  static const defaults = BoatPriceBounds(
    hardMinEur: 100,
    hardMaxEur: 600,
    advisedMinEur: 150,
    advisedMaxEur: 400,
    referenceEur: 240,
  );

  /// Un champ absent ou illisible prend sa valeur par défaut ; des bornes
  /// incohérentes (plancher au-dessus du plafond) rendent [defaults].
  factory BoatPriceBounds.fromJson(Map<String, dynamic> json) {
    double read(String key, double fallback) {
      final raw = json[key];
      final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
      return value != null && value > 0 ? value : fallback;
    }

    final bounds = BoatPriceBounds(
      hardMinEur: read('hardMinEur', defaults.hardMinEur),
      hardMaxEur: read('hardMaxEur', defaults.hardMaxEur),
      advisedMinEur: read('advisedMinEur', defaults.advisedMinEur),
      advisedMaxEur: read('advisedMaxEur', defaults.advisedMaxEur),
      referenceEur: read('referenceEur', defaults.referenceEur),
    );
    if (bounds.hardMinEur > bounds.hardMaxEur ||
        bounds.advisedMinEur > bounds.advisedMaxEur) {
      return defaults;
    }
    return bounds;
  }

  /// Bornes converties dans [currency], au taux FIGÉ du catalogue
  /// ([SupportedCurrency.unitsPerEur]), celui du serveur : plancher arrondi
  /// vers le haut et plafond vers le bas, à l'unité mineure de la devise.
  /// L'écran refuse ainsi exactement ce que le serveur refuse (XOF : 65 596
  /// à 393 574 F CFA).
  BoatPriceBoundsIn inCurrency(SupportedCurrency currency) {
    final rate = currency.unitsPerEur;
    final factor = math.pow(10, currency.minorUnit).toDouble();
    // La petite marge évite qu'un produit flottant (1,08 × 100 = 108,000…01)
    // ne déplace la borne d'une unité mineure.
    double up(double eur) =>
        (eur * rate * factor - 1e-6).ceilToDouble() / factor;
    double down(double eur) =>
        (eur * rate * factor + 1e-6).floorToDouble() / factor;
    // Prix habituel : un montant rond (centaine en franc CFA, unité ailleurs).
    final referenceStep = currency.minorUnit == 0 ? 100.0 : 1.0;
    return BoatPriceBoundsIn(
      currency: currency,
      hardMin: up(hardMinEur),
      hardMax: down(hardMaxEur),
      advisedMin: up(advisedMinEur),
      advisedMax: down(advisedMaxEur),
      reference: (referenceEur * rate / referenceStep).round() * referenceStep,
    );
  }

  @override
  List<Object?> get props => [
    hardMinEur,
    hardMaxEur,
    advisedMinEur,
    advisedMaxEur,
    referenceEur,
  ];
}

/// Borne franchie par un prix au m³.
enum BoatPriceBound { tooLow, tooHigh }

/// [BoatPriceBounds] dans une devise donnée.
@immutable
class BoatPriceBoundsIn extends Equatable {
  final SupportedCurrency currency;
  final double hardMin;
  final double hardMax;
  final double advisedMin;
  final double advisedMax;
  final double reference;

  const BoatPriceBoundsIn({
    required this.currency,
    required this.hardMin,
    required this.hardMax,
    required this.advisedMin,
    required this.advisedMax,
    required this.reference,
  });

  /// Borne dure franchie (le serveur refuserait), `null` sinon ou sans prix.
  BoatPriceBound? hardBoundOf(double? price) {
    if (price == null) return null;
    if (price < hardMin) return BoatPriceBound.tooLow;
    if (price > hardMax) return BoatPriceBound.tooHigh;
    return null;
  }

  /// Hors de la zone conseillée, sans franchir de borne dure.
  BoatPriceBound? advisedBoundOf(double? price) {
    if (price == null || hardBoundOf(price) != null) return null;
    if (price < advisedMin) return BoatPriceBound.tooLow;
    if (price > advisedMax) return BoatPriceBound.tooHigh;
    return null;
  }

  @override
  List<Object?> get props => [
    currency,
    hardMin,
    hardMax,
    advisedMin,
    advisedMax,
    reference,
  ];
}

final ValueNotifier<BoatPriceBounds> _boatPriceBoundsNotifier = ValueNotifier(
  BoatPriceBounds.defaults,
);

/// Dernière valeur connue : chargée au démarrage
/// (`GET /config/boat-price-bounds`), [BoatPriceBounds.defaults] sinon.
ValueListenable<BoatPriceBounds> get boatPriceBoundsListenable =>
    _boatPriceBoundsNotifier;

BoatPriceBounds get boatPriceBounds => _boatPriceBoundsNotifier.value;

void setBoatPriceBounds(BoatPriceBounds value) {
  _boatPriceBoundsNotifier.value = value;
}

@visibleForTesting
void resetBoatPriceBoundsForTest() {
  _boatPriceBoundsNotifier.value = BoatPriceBounds.defaults;
}
