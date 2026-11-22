import 'package:dony/core/utils/lenient_number.dart';
import 'package:equatable/equatable.dart';

/// Palier du barème des frais d'annulation : [rate] s'applique quand il reste
/// au moins [minDaysBefore] jours avant le départ (le palier le plus lointain,
/// fenêtre gratuite, en exige strictement plus côté serveur).
class CancellationFeeTier extends Equatable {
  const CancellationFeeTier({required this.minDaysBefore, required this.rate});

  final int minDaysBefore;

  /// Taux de 0 à 1 (0.10 = 10 %).
  final double rate;

  @override
  List<Object?> get props => [minDaysBefore, rate];
}

/// État public des frais d'annulation de l'expéditeur, servi par
/// `GET /config/cancellation-fee` (public, sans authentification). L'app n'en
/// tire que le choix de ses textes : le serveur reste seul juge des frais.
///
/// Lecture tolérante, champ par champ : la configuration n'est allumée que si
/// `active` est le booléen `true` ET que la date d'effet est lisible (même
/// règle que le serveur, qui ne retient rien tant que la date n'est pas
/// posée) ; plafond et paliers illisibles sont ignorés.
class CancellationFeeConfigModel extends Equatable {
  const CancellationFeeConfigModel({
    this.effectiveFrom,
    this.capEur,
    this.tiers = const [],
  });

  factory CancellationFeeConfigModel.fromJson(Map<String, dynamic> json) {
    final rawFrom = json['effectiveFrom'];
    final effectiveFrom = rawFrom is String
        ? DateTime.tryParse(rawFrom.trim())
        : null;
    final rawTiers = json['tiers'];
    return CancellationFeeConfigModel(
      effectiveFrom: json['active'] == true ? effectiveFrom : null,
      capEur: lenientDoubleOrNull(json['capEur']),
      tiers: rawTiers is List
          ? [for (final t in rawTiers) ?_tierOrNull(t)]
          : const [],
    );
  }

  /// Back antérieur, hors ligne, lecture ratée : les textes d'avant la
  /// fonction.
  static const inactive = CancellationFeeConfigModel();

  /// Seuls les colis créés à cet instant ou après portent des frais. `null`
  /// quand les frais sont éteints ou que la date n'est pas posée.
  final DateTime? effectiveFrom;

  /// Frais allumés ET date d'effet posée.
  bool get active => effectiveFrom != null;

  /// Plafond du frais par annulation, en euros.
  final double? capEur;

  /// Paliers, du plus lointain au plus proche du départ.
  final List<CancellationFeeTier> tiers;

  @override
  List<Object?> get props => [effectiveFrom, capEur, tiers];

  static CancellationFeeTier? _tierOrNull(Object? raw) {
    if (raw is! Map) return null;
    final days = raw['minDaysBefore'];
    final rate = lenientDoubleOrNull(raw['rate']);
    if (days is! num || rate == null) return null;
    return CancellationFeeTier(minDaysBefore: days.toInt(), rate: rate);
  }
}
