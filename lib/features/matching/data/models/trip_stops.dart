import 'package:dony/features/matching/data/models/transport_mode.dart';

/// Escales d'un trajet en avion (FLUTTER-GE), information facultative.
///
/// Fil : `stopsCount` entier, 0 = direct, 1 = une escale, 2 = deux escales ou
/// plus. Absent ou nul = non renseigné : rien n'est affiché. Seul l'avion porte
/// cette information (le serveur l'efface pour les autres modes).
enum TripStops {
  direct(0),
  one(1),
  twoOrMore(2);

  const TripStops(this.wire);

  final int wire;
}

/// Lecture tolérante : valeur absente, inconnue ou négative = non renseigné ;
/// au-delà de 2, « deux escales ou plus ».
TripStops? tripStopsFromWire(Object? raw) {
  if (raw is! num) {
    return null;
  }
  final value = raw.toInt();
  if (value < 0) {
    return null;
  }
  if (value == 0) {
    return TripStops.direct;
  }
  if (value == 1) {
    return TripStops.one;
  }
  return TripStops.twoOrMore;
}

int? tripStopsToWire(TripStops? stops) => stops?.wire;

/// Le champ « escales » n'a de sens que pour un trajet en avion.
bool supportsStops(TransportMode? mode) => mode == TransportMode.plane;

/// Filtre de recherche « Escales » (FLUTTER-GD). `null` = peu importe.
///
/// Envoyé au serveur en `maxStops`. « Direct uniquement » écarte les trajets
/// dont le voyageur n'a pas renseigné les escales ; « Max 1 escale » les garde.
enum StopsFilter {
  directOnly(0),
  maxOne(1);

  const StopsFilter(this.maxStops);

  final int maxStops;
}
