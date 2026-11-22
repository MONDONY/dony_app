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
/// Lecture tolérante, champ par champ : `active` n'est vrai que pour le
/// booléen `true` ; allumé sans date d'effet lisible, la configuration est
/// traitée comme éteinte (même règle que le serveur, qui ne retient rien tant
/// que la date n'est pas posée) ; plafond et paliers illisibles sont ignorés.
class CancellationFeeConfigModel extends Equatable {
  const CancellationFeeConfigModel({
    required this.active,
    this.effectiveFrom,
    this.capEur,
    this.tiers = const [],
  });

  factory CancellationFeeConfigModel.fromJson(Map<String, dynamic> json) {
    final rawFrom = json['effectiveFrom'];
    final effectiveFrom = rawFrom is String
        ? DateTime.tryParse(rawFrom.trim())
        : null;
    final active = json['active'] == true && effectiveFrom != null;
    final rawTiers = json['tiers'];
    return CancellationFeeConfigModel(
      active: active,
      effectiveFrom: active ? effectiveFrom : null,
      capEur: _decimalOrNull(json['capEur']),
      tiers: rawTiers is List
          ? [for (final t in rawTiers) ?_tierOrNull(t)]
          : const [],
    );
  }

  /// Back antérieur, hors ligne, lecture ratée : les textes d'avant la
  /// fonction.
  static const inactive = CancellationFeeConfigModel(active: false);

  /// Frais allumés ET date d'effet posée.
  final bool active;

  /// Seuls les colis créés à cet instant ou après portent des frais. `null`
  /// quand [active] est faux.
  final DateTime? effectiveFrom;

  /// Plafond du frais par annulation, en euros.
  final double? capEur;

  /// Paliers, du plus lointain au plus proche du départ.
  final List<CancellationFeeTier> tiers;

  @override
  List<Object?> get props => [active, effectiveFrom, capEur, tiers];

  static CancellationFeeTier? _tierOrNull(Object? raw) {
    if (raw is! Map) return null;
    final days = raw['minDaysBefore'];
    final rate = _decimalOrNull(raw['rate']);
    if (days is! num || rate == null) return null;
    return CancellationFeeTier(minDaysBefore: days.toInt(), rate: rate);
  }

  static double? _decimalOrNull(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim());
    return null;
  }
}
