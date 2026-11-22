import 'package:dony/features/cancellation/data/models/cancellation_fee_config_model.dart';

/// Ligne du barème des frais d'annulation, lue des paliers de la
/// configuration publique (jamais de seuil ni de taux en dur dans l'app).
enum CancellationFeeScaleKind {
  /// Palier le plus lointain : « Plus de [days] jours avant le départ ».
  moreThan,

  /// Palier intermédiaire : « De [fromDays] jours à [days] jours ».
  between,

  /// Palier le plus proche (0 jour) : « Moins de [days] jours, jour du
  /// départ ou après ».
  lessThan,
}

class CancellationFeeScaleRow {
  const CancellationFeeScaleRow({
    required this.kind,
    required this.days,
    required this.percent,
    this.fromDays,
  });

  final CancellationFeeScaleKind kind;

  /// Jours du seuil de la ligne (le seuil lointain pour [moreThan] et
  /// [between] côté arrivée, le seuil du palier précédent pour [lessThan]).
  final int days;

  /// Départ de la plage pour [between] ; `null` sinon.
  final int? fromDays;

  /// Taux en pourcentage entier (0 = aucun frais).
  final int percent;
}

/// Barème à afficher avant de payer.
class CancellationFeeScale {
  const CancellationFeeScale({required this.rows, this.capEur});

  final List<CancellationFeeScaleRow> rows;

  /// Plafond par colis en euros ; `null` quand le serveur ne le donne pas
  /// (ligne « Plafond » omise).
  final double? capEur;

  /// Barème de la [config], ou `null` quand il ne doit pas être montré :
  /// frais éteints, pas encore en vigueur à [now], paliers vides ou
  /// incohérents (moins de deux paliers, seuils non strictement décroissants,
  /// négatifs, taux hors de 0 à 1 ou qui baissent quand le départ approche).
  static CancellationFeeScale? fromConfig(
    CancellationFeeConfigModel config, {
    required DateTime now,
  }) {
    final from = config.effectiveFrom;
    if (from == null || now.isBefore(from)) return null;
    final tiers = config.tiers;
    if (tiers.length < 2) return null;
    for (var i = 0; i < tiers.length; i++) {
      final t = tiers[i];
      if (t.minDaysBefore < 0 || t.rate < 0 || t.rate > 1) return null;
      // Un taux à fraction de pourcent serait arrondi : un faux chiffre.
      final pct = t.rate * 100;
      if ((pct - pct.roundToDouble()).abs() > 1e-6) return null;
      if (i > 0) {
        final prev = tiers[i - 1];
        if (t.minDaysBefore >= prev.minDaysBefore) return null;
        if (t.rate < prev.rate) return null;
      }
    }
    // Sans palier à 0 jour, rien ne dirait ce qui s'applique après le dernier
    // seuil.
    if (tiers.last.minDaysBefore != 0) return null;
    final rows = <CancellationFeeScaleRow>[];
    for (var i = 0; i < tiers.length; i++) {
      final t = tiers[i];
      final percent = (t.rate * 100).round();
      if (i == 0) {
        rows.add(
          CancellationFeeScaleRow(
            kind: CancellationFeeScaleKind.moreThan,
            days: t.minDaysBefore,
            percent: percent,
          ),
        );
      } else if (i == tiers.length - 1) {
        rows.add(
          CancellationFeeScaleRow(
            kind: CancellationFeeScaleKind.lessThan,
            days: tiers[i - 1].minDaysBefore,
            percent: percent,
          ),
        );
      } else {
        rows.add(
          CancellationFeeScaleRow(
            kind: CancellationFeeScaleKind.between,
            fromDays: tiers[i - 1].minDaysBefore,
            days: t.minDaysBefore,
            percent: percent,
          ),
        );
      }
    }
    final cap = config.capEur;
    return CancellationFeeScale(
      rows: rows,
      capEur: cap != null && cap > 0 ? cap : null,
    );
  }
}
