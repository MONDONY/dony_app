import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_exif/native_exif.dart';

/// Position enregistrée avec une étape : coordonnées et lieu lisible.
class ScanPosition {
  const ScanPosition({required this.lat, required this.lon, this.label});

  final double lat;
  final double lon;

  /// « Rue, ville, pays », `null` si le géocodage inverse a échoué.
  final String? label;
}

/// Position du voyageur au moment d'une étape, et son inscription dans les
/// métadonnées EXIF de la photo. Jamais bloquant : sans permission ou sans
/// signal, l'étape part sans position.
class ScanLocator {
  const ScanLocator();

  /// Position actuelle, `null` sans permission ou en cas d'échec.
  Future<ScanPosition?> capture() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return ScanPosition(
        lat: position.latitude,
        lon: position.longitude,
        label: await _resolveLabel(position.latitude, position.longitude),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolveLabel(double lat, double lon) async {
    try {
      final places = await placemarkFromCoordinates(lat, lon);
      if (places.isEmpty) return null;
      return formatPlacemark(places.first);
    } catch (_) {
      return null;
    }
  }

  /// « Rue, ville, région » : trois parties au plus, sans doublon.
  static String? formatPlacemark(Placemark place) {
    final unique = <String>[];
    for (final part in [
      place.street,
      place.locality,
      place.administrativeArea,
      place.country,
    ]) {
      final trimmed = part?.trim();
      if (trimmed == null || trimmed.isEmpty) continue;
      if (!unique.contains(trimmed)) unique.add(trimmed);
    }
    return unique.isEmpty ? null : unique.take(3).join(', ');
  }

  /// Inscrit [position] dans l'EXIF de la photo. Un échec est ignoré : la
  /// position part de toute façon avec l'étape.
  Future<void> writeExif(String path, ScanPosition position) async {
    try {
      final exif = await Exif.fromPath(path);
      // Clés EXIF standard, jamais traduites (i18n-ignore).
      await exif.writeAttributes({
        'GPSLatitude': toExifDms(position.lat.abs()), // i18n-ignore
        'GPSLatitudeRef': position.lat >= 0 ? 'N' : 'S', // i18n-ignore
        'GPSLongitude': toExifDms(position.lon.abs()), // i18n-ignore
        'GPSLongitudeRef': position.lon >= 0 ? 'E' : 'W', // i18n-ignore
      });
      await exif.close();
    } catch (_) {}
  }

  /// Degrés décimaux en rationnels EXIF « d/1,m/1,s/100 ».
  static String toExifDms(double decimal) {
    final deg = decimal.floor();
    final minFull = (decimal - deg) * 60;
    final min = minFull.floor();
    final sec = ((minFull - min) * 60 * 100).round();
    return '$deg/1,$min/1,$sec/100';
  }
}
