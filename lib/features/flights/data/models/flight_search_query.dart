import 'package:dony/features/flights/data/models/flight_passengers.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// Date de départ ou de retour du formulaire : un jour précis, ou tout le mois
/// de [date] quand [wholeMonth] est vrai. Le back accepte les deux formes
/// (`AAAA-MM-JJ` ou `AAAA-MM`).
class FlightWhen extends Equatable {
  const FlightWhen.day(this.date) : wholeMonth = false;
  const FlightWhen.month(this.date) : wholeMonth = true;

  final DateTime date;
  final bool wholeMonth;

  String toQueryValue() => wholeMonth
      ? DateFormat('yyyy-MM').format(date)
      : DateFormat('yyyy-MM-dd').format(date);

  /// Premier jour couvert.
  DateTime get first =>
      wholeMonth ? DateTime(date.year, date.month) : _day(date);

  /// Dernier jour couvert.
  DateTime get last =>
      wholeMonth ? DateTime(date.year, date.month + 1, 0) : _day(date);

  @override
  List<Object?> get props => [
    date.year,
    date.month,
    wholeMonth ? 0 : date.day,
    wholeMonth,
  ];
}

/// Tronque à minuit sans dépendre de Flutter (modèle pur, testable en Dart).
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Recherche saisie dans l'onglet Billets.
class FlightSearchQuery extends Equatable {
  const FlightSearchQuery({
    this.origin,
    this.destination,
    this.departure,
    this.returnDate,
    this.directOnly = false,
    this.passengers = FlightPassengers.single,
    bool? roundTrip,
  }) : roundTrip = roundTrip ?? returnDate != null;

  final FlightPlace? origin;
  final FlightPlace? destination;
  final FlightWhen? departure;

  /// Date du retour, envoyée au back : présente = aller-retour.
  final FlightWhen? returnDate;
  final bool directOnly;

  /// Passagers choisis : ils partent avec le clic (lien Aviasales), jamais
  /// avec la recherche, dont les prix restent par adulte.
  final FlightPassengers passengers;

  /// Choix « Aller-retour » du sélecteur du formulaire. Peut être vrai sans
  /// [returnDate] tant que la date du retour n'est pas choisie : le bouton de
  /// recherche ouvre alors la feuille des dates.
  final bool roundTrip;

  /// Aller-retour choisi mais date du retour encore manquante.
  bool get needsReturnDate => roundTrip && returnDate == null;

  bool get isComplete =>
      origin != null &&
      destination != null &&
      origin!.code != destination!.code;

  bool get isRoundTrip => returnDate != null;

  FlightSearchQuery copyWith({
    FlightPlace? origin,
    FlightPlace? destination,
    FlightWhen? departure,
    FlightWhen? returnDate,
    bool clearReturn = false,
    bool? directOnly,
    FlightPassengers? passengers,
    bool? roundTrip,
  }) => FlightSearchQuery(
    origin: origin ?? this.origin,
    destination: destination ?? this.destination,
    departure: departure ?? this.departure,
    returnDate: clearReturn ? null : (returnDate ?? this.returnDate),
    directOnly: directOnly ?? this.directOnly,
    passengers: passengers ?? this.passengers,
    roundTrip: roundTrip ?? this.roundTrip,
  );

  /// Départ et arrivée échangés (bouton d'inversion du formulaire).
  FlightSearchQuery swapped() => FlightSearchQuery(
    origin: destination,
    destination: origin,
    departure: departure,
    returnDate: returnDate,
    directOnly: directOnly,
    passengers: passengers,
    roundTrip: roundTrip,
  );

  @override
  List<Object?> get props => [
    origin,
    destination,
    departure,
    returnDate,
    directOnly,
    passengers,
    roundTrip,
  ];
}
