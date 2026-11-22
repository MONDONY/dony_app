import 'dart:math' as math;

import 'package:dony/core/currency/supported_currency.dart';
import 'package:equatable/equatable.dart';

/// Aperçu des frais d'annulation qu'un expéditeur perdrait s'il annulait son
/// colis maintenant, servi par `GET /cancellations/bids/{bidId}/fee-preview`
/// (yadony-back #779, fonction livrée éteinte).
///
/// Lecture tolérante : un montant arrive en nombre (`20.00`, `19678`, un zéro
/// sans décimale `0`) ou en texte (`"20.00"`) ; un montant rendu absent ou
/// illisible vaut 0. Un aperçu incohérent (un taux sans frais lisibles, des
/// frais sans taux) lève une [FormatException] : il serait affiché « sans
/// frais » à tort, le dialogue le traite comme un aperçu indisponible.
class CancellationFeePreviewModel extends Equatable {
  const CancellationFeePreviewModel({
    required this.rate,
    required this.fee,
    required this.refundAmount,
    this.currency,
    this.nextTierAt,
    this.capped,
  });

  factory CancellationFeePreviewModel.fromJson(Map<String, dynamic> json) {
    final rate = _decimalOrNull(json['rate']) ?? 0;
    final fee = _decimalOrNull(json['fee']);
    if (rate > 0 && (fee == null || fee <= 0)) {
      throw const FormatException('fee-preview: rate without a readable fee');
    }
    if ((fee ?? 0) > 0 && rate <= 0) {
      throw const FormatException('fee-preview: fee without a rate');
    }
    final rawCurrency = json['currency'];
    final rawNext = json['nextTierAt'];
    return CancellationFeePreviewModel(
      rate: rate,
      fee: fee ?? 0,
      refundAmount: _decimalOrNull(json['refundAmount']) ?? 0,
      currency: rawCurrency is String && rawCurrency.trim().isNotEmpty
          ? rawCurrency.trim().toUpperCase()
          : null,
      nextTierAt: rawNext is String ? DateTime.tryParse(rawNext) : null,
      capped: json['capped'] is bool ? json['capped'] as bool : null,
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

  /// Le plafond par colis s'applique, dit par le serveur (`capped`, toujours
  /// présent une fois yadony-back déployé). `null` sur un back antérieur ou
  /// une valeur illisible : [isCapped] déduit alors le plafond lui-même.
  final bool? capped;

  /// Des frais s'appliquent : seul cas où le dialogue change.
  bool get hasFee => fee > 0;

  /// Taux en pourcentage entier (0.2 → 20), pour l'affichage.
  int get ratePercent => (rate * 100).round();

  /// Le taux peut encore monter si l'expéditeur attend.
  bool get willRise => nextTierAt != null;

  /// Le plafond par colis s'applique (côté back : frais = min(payé × taux,
  /// plafond), 30 € convertis dans la devise du paiement). Le serveur ne le
  /// dit pas : l'app le déduit. Payé = frais + rendu ; plafonné quand les
  /// frais sont plus bas que payé × taux de PLUS d'une unité de la devise (un
  /// centime en euro, un franc en franc CFA, qui n'a pas de décimale), pour
  /// ne jamais prendre un arrondi à l'unité pour un plafond.
  /// [fallbackCurrency] : devise du colis quand l'aperçu n'en donne pas.
  bool isCapped({String? fallbackCurrency}) {
    final fromServer = capped;
    if (fromServer != null) return fromServer;
    if (!hasFee || rate <= 0) return false;
    final digits = SupportedCurrency.fromCodeOrDefault(
      currency ?? fallbackCurrency,
    ).minorUnit;
    final paid = fee + refundAmount;
    final gapInMinorUnits = (paid * rate - fee) * math.pow(10, digits);
    return gapInMinorUnits > 1 + _tolerance;
  }

  /// Marge des calculs en virgule flottante (0,1 + 0,2 ≠ 0,3), en unités de
  /// la devise : bien en dessous d'une unité, bien au-dessus du bruit.
  static const _tolerance = 1e-6;

  @override
  List<Object?> get props => [
    rate,
    fee,
    refundAmount,
    currency,
    nextTierAt,
    capped,
  ];

  static double? _decimalOrNull(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim());
    return null;
  }
}
