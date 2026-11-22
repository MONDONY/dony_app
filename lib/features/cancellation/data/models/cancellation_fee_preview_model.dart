import 'package:equatable/equatable.dart';

/// Aperçu des frais d'annulation qu'un expéditeur perdrait s'il annulait son
/// colis maintenant, servi par `GET /cancellations/bids/{bidId}/fee-preview`
/// (yadony-back #779, fonction livrée éteinte).
///
/// Lecture tolérante : un montant arrive en nombre (`20.00`, `19678`, un zéro
/// sans décimale `0`) ou en texte (`"20.00"`) ; un champ absent ou illisible
/// vaut 0, ce qui revient à « aucun frais » et laisse le dialogue d'annulation
/// tel qu'il était avant la fonction.
class CancellationFeePreviewModel extends Equatable {
  const CancellationFeePreviewModel({
    required this.rate,
    required this.fee,
    required this.refundAmount,
    this.currency,
    this.nextTierAt,
  });

  factory CancellationFeePreviewModel.fromJson(Map<String, dynamic> json) {
    final rawCurrency = json['currency'];
    final rawNext = json['nextTierAt'];
    return CancellationFeePreviewModel(
      rate: _decimal(json['rate']),
      fee: _decimal(json['fee']),
      refundAmount: _decimal(json['refundAmount']),
      currency: rawCurrency is String && rawCurrency.trim().isNotEmpty
          ? rawCurrency.trim().toUpperCase()
          : null,
      nextTierAt: rawNext is String ? DateTime.tryParse(rawNext) : null,
    );
  }

  /// Taux appliqué (0.20 = 20 %), 0 quand aucun frais ne s'applique.
  final double rate;

  /// Frais BRUTS retenus : ce que perd l'expéditeur (jamais la part du
  /// voyageur), dans la devise du paiement.
  final double fee;

  /// Montant rendu à l'expéditeur (payé moins [fee]). 0 quand rien n'a été
  /// payé en ligne (espèces).
  final double refundAmount;

  /// Devise ISO 4217 des montants, `null` si le serveur ne l'a pas donnée
  /// (l'écran se rabat alors sur la devise du colis).
  final String? currency;

  /// Dernier instant (inclus) du taux affiché : passé cet instant, le taux
  /// monte. Absent au palier le plus cher ou quand aucun frais n'est possible.
  final DateTime? nextTierAt;

  /// Des frais s'appliquent : seul cas où le dialogue change.
  bool get hasFee => fee > 0;

  /// Taux en pourcentage entier (0.2 → 20), pour l'affichage.
  int get ratePercent => (rate * 100).round();

  /// Le taux peut encore monter si l'expéditeur attend.
  bool get willRise => nextTierAt != null;

  @override
  List<Object?> get props => [rate, fee, refundAmount, currency, nextTierAt];

  static double _decimal(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim()) ?? 0;
    return 0;
  }
}
