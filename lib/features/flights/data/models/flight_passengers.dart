import 'package:equatable/equatable.dart';

/// Catégorie de passager du compteur de la feuille « Passagers ».
enum FlightPassengerKind { adults, children, infants }

/// Passagers d'une recherche de billets : adultes (12 ans et plus), enfants
/// (2 à 11 ans) et bébés (moins de 2 ans, un par adulte). Les prix de
/// recherche restent par adulte : ce choix part seulement avec le clic
/// (`POST /flights/clicks`), qui réécrit le lien Aviasales.
class FlightPassengers extends Equatable {
  const FlightPassengers({
    this.adults = 1,
    this.children = 0,
    this.infants = 0,
  });

  /// Un adulte seul : la recherche par défaut, et le comportement d'avant.
  static const single = FlightPassengers();

  /// Bornes du back (`FlightClickRequest`).
  static const maxTotal = 9;
  static const minAdults = 1;

  /// Lecture tolérante (historique Hive) : absent ou invalide = un adulte.
  static FlightPassengers tryParse(Object? raw) {
    if (raw is! Map) return single;
    int count(String key, int fallback) {
      final v = raw[key];
      return v is num ? v.toInt() : fallback;
    }

    final p = FlightPassengers(
      adults: count('adults', 1),
      children: count('children', 0),
      infants: count('infants', 0),
    );
    return p.isValid ? p : single;
  }

  final int adults;
  final int children;
  final int infants;

  int get total => adults + children + infants;

  bool get isSingle => this == single;

  /// Aucun enfant ni bébé : le prix par adulte donne un total fiable.
  bool get adultsOnly => children == 0 && infants == 0;

  bool get isValid =>
      adults >= minAdults &&
      adults <= maxTotal &&
      children >= 0 &&
      infants >= 0 &&
      infants <= adults &&
      total <= maxTotal;

  int count(FlightPassengerKind kind) => switch (kind) {
    FlightPassengerKind.adults => adults,
    FlightPassengerKind.children => children,
    FlightPassengerKind.infants => infants,
  };

  /// Le « + » de [kind] reste valide : neuf passagers au plus, un bébé par
  /// adulte.
  bool canIncrement(FlightPassengerKind kind) =>
      total < maxTotal &&
      (kind != FlightPassengerKind.infants || infants < adults);

  /// Le « − » de [kind] reste valide : un adulte au moins, et jamais moins
  /// d'adultes que de bébés.
  bool canDecrement(FlightPassengerKind kind) => switch (kind) {
    FlightPassengerKind.adults => adults > minAdults && infants < adults,
    FlightPassengerKind.children => children > 0,
    FlightPassengerKind.infants => infants > 0,
  };

  FlightPassengers increment(FlightPassengerKind kind) =>
      canIncrement(kind) ? _shift(kind, 1) : this;

  FlightPassengers decrement(FlightPassengerKind kind) =>
      canDecrement(kind) ? _shift(kind, -1) : this;

  FlightPassengers _shift(FlightPassengerKind kind, int delta) =>
      FlightPassengers(
        adults: adults + (kind == FlightPassengerKind.adults ? delta : 0),
        children: children + (kind == FlightPassengerKind.children ? delta : 0),
        infants: infants + (kind == FlightPassengerKind.infants ? delta : 0),
      );

  Map<String, dynamic> toJson() => {
    'adults': adults,
    'children': children,
    'infants': infants,
  };

  /// Fragment de [FlightRecentSearch.dedupKey] : « 2-1-0 ».
  String get key => '$adults-$children-$infants';

  @override
  List<Object?> get props => [adults, children, infants];
}
