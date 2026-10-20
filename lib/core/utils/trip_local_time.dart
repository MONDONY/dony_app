import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Heure d'un instant UTC dans le fuseau du trajet (YADONY-FLUTTER-PROD-1R).
///
/// Le back envoie la date limite de dépôt et la limite de décision d'un
/// report en UTC, et le fuseau IANA de la ville de départ
/// (`departureTimezone`). Le départ s'affiche déjà à l'heure de cette ville :
/// la date limite doit suivre, sinon un expéditeur à Dakar lisait 18:30 pour
/// une limite fixée à 20:30, heure de Paris.
class TripWallTime {
  const TripWallTime(this.wallClock, {required this.differsFromDevice});

  /// Champs d'heure murale de la ville (année ... minute), portés par un
  /// `DateTime` UTC pour qu'aucun formatage ne les reconvertisse.
  final DateTime wallClock;

  /// Le fuseau du trajet n'a pas le décalage de l'appareil à cet instant :
  /// l'heure affichée doit alors nommer la ville.
  final bool differsFromDevice;
}

bool _timeZonesLoaded = false;

/// Charge la base des fuseaux à la première conversion (synchrone, sans
/// plateforme : fonctionne aussi dans les tests).
void _ensureTimeZones() {
  if (_timeZonesLoaded) return;
  tz_data.initializeTimeZones();
  _timeZonesLoaded = true;
}

tz.Location? _locationOf(String? timezone) {
  final name = timezone?.trim();
  if (name == null || name.isEmpty) return null;
  _ensureTimeZones();
  try {
    return tz.getLocation(name);
  } on tz.LocationNotFoundException {
    return null;
  }
}

/// Convertit [instant] dans le fuseau [timezone]. Fuseau absent (back
/// antérieur à #627) ou inconnu : repli sur l'heure de l'appareil.
///
/// [deviceOffset] remplace le décalage de l'appareil (tests).
TripWallTime tripWallTime(
  DateTime instant,
  String? timezone, {
  Duration? deviceOffset,
}) {
  final location = _locationOf(timezone);
  if (location == null) {
    final local = instant.toLocal();
    return TripWallTime(
      DateTime.utc(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
      ),
      differsFromDevice: false,
    );
  }
  final zoned = tz.TZDateTime.from(instant, location);
  final device = deviceOffset ?? instant.toLocal().timeZoneOffset;
  return TripWallTime(
    DateTime.utc(
      zoned.year,
      zoned.month,
      zoned.day,
      zoned.hour,
      zoned.minute,
      zoned.second,
    ),
    differsFromDevice: zoned.timeZoneOffset != device,
  );
}

const _vowels =
    'AEIOUÀÂÄÉÈÊËÎÏÔÖÙÛÜ'; // i18n-ignore : voyelles pour l'élision, pas un texte affiché

/// « 20:30 », ou « 20:30, heure de Paris » / « 8:30 PM, Paris time » quand
/// le fuseau du trajet diffère de celui de l'appareil. [city] = ville de
/// départ du trajet.
String formatTripTime(AppLocalizations l, TripWallTime t, {String? city}) {
  final time = DateFormat.jm(l.localeName).format(t.wallClock);
  return withTripCity(l, time, t, city: city);
}

/// Ajoute la ville à un libellé d'heure déjà formaté, seulement quand le
/// fuseau du trajet diffère de celui de l'appareil.
String withTripCity(
  AppLocalizations l,
  String time,
  TripWallTime t, {
  String? city,
}) {
  final name = city?.trim();
  if (!t.differsFromDevice || name == null || name.isEmpty) return time;
  final elided = _vowels.contains(name[0].toUpperCase());
  return elided
      ? l.tripTimeInCityElided(time, name)
      : l.tripTimeInCity(time, name);
}
