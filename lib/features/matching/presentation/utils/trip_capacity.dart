import 'package:dony/features/matching/data/models/announcement_model.dart';

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
