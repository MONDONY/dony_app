import 'package:latlong2/latlong.dart';

enum CityType { departure, arrival }

class City {
  final String id;
  final String displayName;
  final String country;
  final LatLng coordinates;
  final CityType type;

  const City({
    required this.id,
    required this.displayName,
    required this.country,
    required this.coordinates,
    required this.type,
  });
}

class CityConstants {
  CityConstants._();

  static const List<City> all = [
    City(id: 'paris',     displayName: 'Paris',     country: 'France',          coordinates: LatLng(48.8566, 2.3522),   type: CityType.departure),
    City(id: 'lyon',      displayName: 'Lyon',      country: 'France',          coordinates: LatLng(45.7640, 4.8357),   type: CityType.departure),
    City(id: 'marseille', displayName: 'Marseille', country: 'France',          coordinates: LatLng(43.2965, 5.3698),   type: CityType.departure),
    City(id: 'dakar',     displayName: 'Dakar',     country: 'Sénégal',         coordinates: LatLng(14.7167, -17.4677), type: CityType.arrival),
    City(id: 'abidjan',   displayName: 'Abidjan',   country: "Côte d'Ivoire",   coordinates: LatLng(5.3599, -4.0083),   type: CityType.arrival),
    City(id: 'bamako',    displayName: 'Bamako',    country: 'Mali',            coordinates: LatLng(12.6392, -8.0029),  type: CityType.arrival),
    City(id: 'douala',    displayName: 'Douala',    country: 'Cameroun',        coordinates: LatLng(4.0511, 9.7679),    type: CityType.arrival),
  ];

  static List<City> get departures =>
      all.where((c) => c.type == CityType.departure).toList();

  static List<City> get arrivals =>
      all.where((c) => c.type == CityType.arrival).toList();

  static City? findById(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  static City? findNearest(LatLng position, {double maxDistanceKm = 50}) {
    const distanceFn = Distance();
    City? nearest;
    double minDist = double.infinity;

    for (final city in departures) {
      final km = distanceFn.as(LengthUnit.Kilometer, position, city.coordinates);
      if (km < minDist) {
        minDist = km;
        nearest = city;
      }
    }

    if (nearest == null || minDist > maxDistanceKm) return null;
    return nearest;
  }
}
