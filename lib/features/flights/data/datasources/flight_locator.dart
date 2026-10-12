import 'dart:math' as math;

import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:geolocator/geolocator.dart';

/// Noms accentués, gardés hors du tableau pour le garde-fou i18n (noms
/// propres, identiques dans les deux langues).
const _geneve = 'Genève'; // i18n-ignore
const _montreal = 'Montréal'; // i18n-ignore
const _yaounde = 'Yaoundé'; // i18n-ignore
const _lome = 'Lomé'; // i18n-ignore

/// Ville d'aéroport la plus proche du téléphone, pour « Utiliser ma
/// position » du choix de la ville de départ.
///
/// Ne demande jamais la permission : la ligne ne s'affiche que si l'app l'a
/// déjà obtenue ailleurs (adresse de retrait, détection du pays). Une demande
/// ici, au milieu d'une saisie de ville, surprendrait plus qu'elle n'aiderait.
abstract class FlightLocator {
  /// Vrai si la position est lisible sans rien demander à l'utilisateur.
  Future<bool> canLocate();

  /// Ville la plus proche dans un rayon de [maxDistanceKm], `null` sinon.
  Future<FlightPlace?> nearestCity();
}

class GeoFlightLocator implements FlightLocator {
  const GeoFlightLocator({this.maxDistanceKm = 150});

  final double maxDistanceKm;

  /// Villes d'aéroport reconnues, avec leurs coordonnées (centre-ville). Noms
  /// propres, identiques en français et en anglais.
  static const cities = <(FlightPlace, double, double)>[
    (
      FlightPlace(code: 'PAR', name: 'Paris', countryCode: 'FR'),
      48.8566,
      2.3522,
    ),
    (
      FlightPlace(code: 'LYS', name: 'Lyon', countryCode: 'FR'),
      45.7640,
      4.8357,
    ),
    (
      FlightPlace(code: 'MRS', name: 'Marseille', countryCode: 'FR'),
      43.2965,
      5.3698,
    ),
    (
      FlightPlace(code: 'NCE', name: 'Nice', countryCode: 'FR'),
      43.7102,
      7.2620,
    ),
    (
      FlightPlace(code: 'TLS', name: 'Toulouse', countryCode: 'FR'),
      43.6047,
      1.4442,
    ),
    (
      FlightPlace(code: 'BOD', name: 'Bordeaux', countryCode: 'FR'),
      44.8378,
      -0.5792,
    ),
    (
      FlightPlace(code: 'LIL', name: 'Lille', countryCode: 'FR'),
      50.6292,
      3.0573,
    ),
    (
      FlightPlace(code: 'NTE', name: 'Nantes', countryCode: 'FR'),
      47.2184,
      -1.5536,
    ),
    (
      FlightPlace(code: 'BRU', name: 'Bruxelles', countryCode: 'BE'),
      50.8503,
      4.3517,
    ),
    (
      FlightPlace(code: 'GVA', name: _geneve, countryCode: 'CH'),
      46.2044,
      6.1432,
    ),
    (
      FlightPlace(code: 'LON', name: 'Londres', countryCode: 'GB'),
      51.5074,
      -0.1278,
    ),
    (
      FlightPlace(code: 'MAD', name: 'Madrid', countryCode: 'ES'),
      40.4168,
      -3.7038,
    ),
    (
      FlightPlace(code: 'MIL', name: 'Milan', countryCode: 'IT'),
      45.4642,
      9.1900,
    ),
    (
      FlightPlace(code: 'YMQ', name: _montreal, countryCode: 'CA'),
      45.5017,
      -73.5673,
    ),
    (
      FlightPlace(code: 'NYC', name: 'New York', countryCode: 'US'),
      40.7128,
      -74.0060,
    ),
    (
      FlightPlace(code: 'DKR', name: 'Dakar', countryCode: 'SN'),
      14.7167,
      -17.4677,
    ),
    (
      FlightPlace(code: 'ABJ', name: 'Abidjan', countryCode: 'CI'),
      5.3599,
      -4.0083,
    ),
    (
      FlightPlace(code: 'BKO', name: 'Bamako', countryCode: 'ML'),
      12.6392,
      -8.0029,
    ),
    (
      FlightPlace(code: 'DLA', name: 'Douala', countryCode: 'CM'),
      4.0511,
      9.7679,
    ),
    (
      FlightPlace(code: 'NSI', name: _yaounde, countryCode: 'CM'),
      3.8480,
      11.5021,
    ),
    (
      FlightPlace(code: 'CMN', name: 'Casablanca', countryCode: 'MA'),
      33.5731,
      -7.5898,
    ),
    (
      FlightPlace(code: 'COO', name: 'Cotonou', countryCode: 'BJ'),
      6.3703,
      2.3912,
    ),
    (FlightPlace(code: 'LFW', name: _lome, countryCode: 'TG'), 6.1319, 1.2228),
    (
      FlightPlace(code: 'CKY', name: 'Conakry', countryCode: 'GN'),
      9.6412,
      -13.5784,
    ),
    (
      FlightPlace(code: 'OUA', name: 'Ouagadougou', countryCode: 'BF'),
      12.3714,
      -1.5197,
    ),
    (
      FlightPlace(code: 'NIM', name: 'Niamey', countryCode: 'NE'),
      13.5116,
      2.1254,
    ),
    (
      FlightPlace(code: 'LBV', name: 'Libreville', countryCode: 'GA'),
      0.4162,
      9.4673,
    ),
  ];

  @override
  Future<bool> canLocate() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return false;
      }
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<FlightPlace?> nearestCity() async {
    try {
      final position =
          await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 8),
            ),
          );
      return nearestTo(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Ville de [cities] la plus proche de ce point, dans le rayon.
  FlightPlace? nearestTo(double latitude, double longitude) {
    FlightPlace? best;
    var bestKm = double.infinity;
    for (final (place, lat, lng) in cities) {
      final km = distanceKm(latitude, longitude, lat, lng);
      if (km < bestKm) {
        bestKm = km;
        best = place;
      }
    }
    return bestKm <= maxDistanceKm ? best : null;
  }

  /// Distance à vol d'oiseau (haversine), calculée ici plutôt que par le
  /// plugin : pur calcul, sans appel à la plateforme.
  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earthKm = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthKm * math.asin(math.sqrt(a));
  }
}
