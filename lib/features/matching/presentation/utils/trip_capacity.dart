import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/utils/format_volume.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Capacité d'un trajet lue en valises (`SUITCASE_23KG` / `SUITCASE_32KG`).
///
/// Le fil ne porte que `capacityUnit`, `totalKg` et `availableKg` : le nombre de
/// valises se déduit du total. Un total qui n'est pas un multiple de la valise
/// (ancien trajet, saisie à la main) rend `null` : l'appelant retombe sur
/// l'affichage en kilos.
class TripCapacity {
  const TripCapacity._({
    required this.count,
    required this.unitKg,
    required this.availableKg,
  });

  /// Nombre de valises offertes.
  final int count;

  /// Poids d'une valise (23 ou 32 kg).
  final int unitKg;

  /// Kilos encore libres sur l'ensemble du trajet.
  final double availableKg;

  /// Lecture de [a], ou `null` quand il ne se découpe pas en valises entières.
  static TripCapacity? fromAnnouncement(AnnouncementModel a) {
    final unit = switch (a.capacityUnit) {
      'SUITCASE_23KG' => 23,
      'SUITCASE_32KG' => 32,
      _ => null,
    };
    if (unit == null || a.totalKg <= 0) {
      return null;
    }
    final count = (a.totalKg / unit).round();
    if (count < 1 || (a.totalKg - count * unit).abs() >= 0.5) {
      return null;
    }
    return TripCapacity._(
      count: count,
      unitKg: unit,
      availableKg: a.availableKg.clamp(0, count * unit.toDouble()).toDouble(),
    );
  }

  double get totalKg => (count * unitKg).toDouble();

  /// Kilos libres de chaque valise : les colis remplissent la première, puis la
  /// suivante.
  List<double> get remainingPerSuitcase {
    var reserved = totalKg - availableKg;
    return List<double>.generate(count, (_) {
      final used = reserved < unitKg ? reserved : unitKg.toDouble();
      reserved -= used;
      return unitKg - used;
    });
  }
}

/// Taille maximale de colis que le trajet affiche : seulement hors avion
/// (un mode absent vaut avion) et quand le voyageur en a posé une. Un avion ne
/// la porte jamais, le back l'efface.
ItemSize? tripShownItemSize(AnnouncementModel a) =>
    transportModeOrPlane(a.transportMode) == TransportMode.plane
    ? null
    : a.maxItemSize;

/// Kilos encore libres, arrondis, avec les milliers groupés (« 1 200 kg
/// dispo », « 1,200 kg available »). Sous 1 000 kg le texte est celui d'avant.
String tripKgAvailableText(AppLocalizations l, AnnouncementModel a) =>
    l.listingKgAvailableLabel(
      NumberFormat('#,##0', l.localeName).format(a.availableKg.roundToDouble()),
    );

/// Capacité d'un trajet en une ligne : valises ou kilos dispo, suivis de la
/// taille maximale de colis quand le trajet en route en porte une (« 1 200 kg
/// dispo, jusqu'à taille L »). Kilo libre : « Kilos libres, jusqu'à taille L ».
/// Sans taille (avion, ancien trajet), la ligne est celle d'avant.
///
/// [detailed] : une capacité en valises ajoute les kilos libres
/// (« 2 valises 23 kg · 40 kg dispo »), pour la fiche du trajet.
String tripCapacityLine(
  AppLocalizations l,
  AnnouncementModel a, {
  bool detailed = false,
}) {
  // Bateau au m³ : le volume restant, jamais un kilo (le trajet n'en porte
  // aucun, `availableKg` y vaut 0 par repli).
  final volume = tripVolumeRemainingText(l, a);
  if (volume != null) return volume;
  final size = tripShownItemSize(a);
  if (a.isKgFree) {
    return size == null ? l.tripKgFree : l.tripCapacityFreeUpToSize(size.code);
  }
  final capacity = TripCapacity.fromAnnouncement(a);
  final kg = tripKgAvailableText(l, a);
  final base = capacity == null
      ? kg
      : detailed
      ? '${l.listingSuitcaseCapacityLabel(capacity.count, capacity.unitKg)} · $kg'
      : l.listingSuitcaseCapacityLabel(capacity.count, capacity.unitKg);
  return size == null ? base : l.tripCapacityUpToSize(base, size.code);
}

/// « 0,4 m³ restants » pour un trajet bateau vendu au m³ ; `null` pour tout
/// autre trajet (kilos, kilo libre). Le volume restant est arrondi vers le bas.
String? tripVolumeRemainingText(AppLocalizations l, AnnouncementModel a) {
  if (!a.isPricedPerM3) return null;
  return l.listingBoatVolumeRemaining(
    formatVolumeRemainingM3(l, a.availableVolumeM3 ?? 0),
  );
}

/// Prix au m³ d'un trajet bateau tel que l'EXPÉDITEUR le lit, frais inclus
/// (« 600 €/m³ ») ; `null` pour un trajet au kilo, `unavailable` pour un trajet
/// au m³ sans prix servi.
String? tripPricePerM3Text(
  AppLocalizations l,
  AnnouncementModel a, {
  bool net = false,
}) {
  if (!a.isPricedPerM3) return null;
  final price = net
      ? (a.pricePerM3 ?? a.pricePerM3Display)
      : a.pricePerM3Display;
  if (price == null || price <= 0) return l.tripPosterPriceUnavailable;
  return l.tripPublishPerM3Value(formatPriceIn(price, a.currency));
}

/// Arrivée estimée d'un trajet bateau : « Arrivée estimée du 12 déc. au 28
/// déc. » (fourchette) ou « Arrivée estimée le 12 déc. » (date seule) ; `null`
/// hors bateau ou sans date d'arrivée. Dates lues en jours calendaires, comme
/// [tripRoadDays]. Un jour d'une autre année que [now] porte son année.
String? tripBoatArrivalText(
  AppLocalizations l,
  AnnouncementModel a, {
  DateTime? now,
}) {
  final arrival = a.arrivalDate;
  if (a.transportMode != TransportMode.boat || arrival == null) return null;
  final year = (now ?? DateTime.now()).year;
  String day(DateTime d) =>
      (d.year == year
              ? DateFormat.MMMd(l.localeName)
              : DateFormat.yMMMd(l.localeName))
          .format(d);
  final max = a.arrivalDateMax;
  final sameDay =
      max != null &&
      max.year == arrival.year &&
      max.month == arrival.month &&
      max.day == arrival.day;
  if (max == null || sameDay || max.isBefore(arrival)) {
    return l.listingBoatArrivalDate(day(arrival));
  }
  return l.listingBoatArrivalRange(day(arrival), day(max));
}

/// « 120 kg max par colis », quand le trajet en route fixe un poids maximal
/// par colis ; `null` sinon.
String? tripMaxParcelLine(AppLocalizations l, AnnouncementModel a) {
  final kg = a.maxParcelWeightKg;
  if (kg == null || kg <= 0) {
    return null;
  }
  if (transportModeOrPlane(a.transportMode) == TransportMode.plane) {
    return null;
  }
  return l.tripMaxParcelWeight(formatWeightKg(l, kg));
}

/// Jours de route d'un trajet en voiture ou en bus dont l'arrivée est datée
/// (au moins 1) ; `null` sinon. Les dates se lisent en jours calendaires
/// (année, mois, jour tels que servis), sans heure ni fuseau : un changement
/// d'heure ou une date en UTC ne décale jamais le compte.
int? tripRoadDays(AnnouncementModel a) {
  final mode = a.transportMode;
  final arrival = a.arrivalDate;
  if (arrival == null ||
      (mode != TransportMode.car && mode != TransportMode.bus)) {
    return null;
  }
  final departure = a.departureDate;
  final days = DateTime.utc(arrival.year, arrival.month, arrival.day)
      .difference(DateTime.utc(departure.year, departure.month, departure.day))
      .inDays;
  return days >= 1 ? days : null;
}
