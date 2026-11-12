import 'package:flutter/material.dart';

enum TransportMode { plane, car, train, bus, boat, other }

const Map<TransportMode, String> _wireByEnum = {
  TransportMode.plane: 'PLANE',
  TransportMode.car: 'CAR',
  TransportMode.train: 'TRAIN',
  TransportMode.bus: 'BUS',
  TransportMode.boat: 'BOAT',
  TransportMode.other: 'OTHER',
};

/// Mode d'un trajet ou d'une demande : un mode absent (anciennes données)
/// vaut avion.
TransportMode transportModeOrPlane(TransportMode? mode) =>
    mode ?? TransportMode.plane;

/// Icône SVG (`assets/icons/`) d'un trajet dont le mode est inconnu ou
/// neutre (train, autre).
const String kNeutralTripIconAsset = 'route';

String transportModeToWire(TransportMode mode) => _wireByEnum[mode]!;

TransportMode? transportModeFromWire(String? wire) {
  if (wire == null) {
    return null;
  }
  for (final entry in _wireByEnum.entries) {
    if (entry.value == wire) {
      return entry.key;
    }
  }
  return null;
}

extension TransportModeUI on TransportMode {
  IconData get icon => switch (this) {
    TransportMode.plane => Icons.flight_rounded,
    TransportMode.car => Icons.directions_car_rounded,
    TransportMode.train => Icons.train_rounded,
    TransportMode.bus => Icons.directions_bus_rounded,
    TransportMode.boat => Icons.directions_boat_rounded,
    TransportMode.other => Icons.commute_rounded,
  };

  /// Nom de l'icône Lucide (`DonyIcon`) du mode. Le bus s'affiche comme la
  /// route ; train et autre prennent l'icône neutre.
  String get iconAsset => switch (this) {
    TransportMode.plane => 'plane',
    TransportMode.boat => 'ship',
    TransportMode.car || TransportMode.bus => 'car',
    TransportMode.train || TransportMode.other => kNeutralTripIconAsset,
  };

  /// Emoji du mode (messages partagés, textes bruts).
  String get emoji => switch (this) {
    TransportMode.plane => '✈️',
    TransportMode.boat => '🚢',
    TransportMode.car || TransportMode.bus => '🚗',
    TransportMode.train => '🚆',
    TransportMode.other => '📦',
  };

  /// Seul l'avion se rattache à des aéroports (codes IATA).
  bool get usesAirportCodes => this == TransportMode.plane;

  /// Mode tel qu'il est regroupé et affiché : le bus compte comme la route.
  TransportMode get displayGroup =>
      this == TransportMode.bus ? TransportMode.car : this;
}

/// Règles par mode, à lire avec les formulaires de trajet et de demande.
///
/// Miroir des règles du back : `ArrivalRules.maxDaysAfterDeparture`,
/// `WeightLimits.isHeavyMode`. Le back reste la source de vérité (un 422 gagne
/// toujours) ; ces valeurs évitent seulement d'envoyer une saisie qu'il
/// refusera. Si une borne change côté back, la changer ici et dans les tests
/// par valeur (`transport_mode_test.dart`), qui servent de parité.
extension TransportModeRules on TransportMode {
  /// Nombre de jours maximum entre le départ et l'arrivée (miroir de
  /// `ArrivalRules`) : 3 pour l'avion, le train et les autres modes, 14 pour
  /// la route, 120 pour le bateau.
  int get maxArrivalDays => switch (this) {
    TransportMode.plane || TransportMode.train || TransportMode.other => 3,
    TransportMode.car || TransportMode.bus => 14,
    TransportMode.boat => 120,
  };

  /// Les valises (23 kg) n'ont pas de sens en voiture ni en bus : on y
  /// compte en kilos libres ou en place, jamais en valises.
  bool get allowsSuitcases => !isRoad;

  /// Seuls la voiture et le bus portent une taille de colis (S à XL).
  bool get hasItemSize => isRoad;

  /// Route : voiture ou bus.
  bool get isRoad => this == TransportMode.car || this == TransportMode.bus;

  /// Mode « lourd » (voiture, bus, bateau) : poids et capacités en tonnes.
  /// Miroir de `WeightLimits.isHeavyMode`.
  bool get isHeavy => isRoad || this == TransportMode.boat;
}

/// Capacité maximale qu'un voyageur peut saisir pour un trajet, en kilos
/// entiers (miroir de `WeightLimits.maxTripCapacity`).
abstract final class TripCapacityLimits {
  /// Hors route et bateau : 999 kg (trajet avion 999,99 côté back, la saisie
  /// est en kilos entiers).
  static const int standardMaxKg = 999;

  /// Route et bateau : 999 999 kg (999 999,99 côté back, kilos entiers saisis).
  static const int heavyMaxKg = 999999;

  static int maxKgFor(TransportMode mode) =>
      mode.isHeavy ? heavyMaxKg : standardMaxKg;

  /// Série de trajets hors route et bateau : 40 kg (miroir de
  /// `WeightLimits.PLANE_RECURRENCE_MAX_KG` et `maxRecurrenceCapacity` côté
  /// back, 422 `trip-capacity-too-high`).
  static const int standardSeriesMaxKg = 40;

  /// Capacité maximale d'une série de trajets : 40 kg en avion, celle d'un
  /// trajet en route et en bateau.
  static int seriesMaxKgFor(TransportMode mode) =>
      mode.isHeavy ? heavyMaxKg : standardSeriesMaxKg;
}
