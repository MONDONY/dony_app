import 'package:dony/features/matching/data/models/commission_funding_detail.dart';
import 'package:equatable/equatable.dart';

/// Un portefeuille débité pour régler la commission : montant dans sa devise,
/// part de la commission qu'il règle (devise du colis) et taux du jour utilisé.
class CommissionAllocationLine extends Equatable {
  const CommissionAllocationLine({
    required this.currency,
    required this.debitAmount,
    required this.coveredInBid,
    this.rateOfTheDay,
  });

  final String currency;
  final double debitAmount;
  final double coveredInBid;

  /// Unités de [currency] pour UNE unité de la devise du colis. `null` pour le
  /// portefeuille de la devise du colis (aucune conversion).
  final double? rateOfTheDay;

  bool get converted => rateOfTheDay != null;

  factory CommissionAllocationLine.fromJson(Map<String, dynamic> json) =>
      CommissionAllocationLine(
        currency: (json['currency'] as String).toUpperCase(),
        debitAmount: (json['debitAmount'] as num).toDouble(),
        coveredInBid: (json['coveredInBid'] as num).toDouble(),
        rateOfTheDay: (json['rateOfTheDay'] as num?)?.toDouble(),
      );

  @override
  List<Object?> get props => [
    currency,
    debitAmount,
    coveredInBid,
    rateOfTheDay,
  ];
}

/// Aperçu, avant l'acceptation d'un colis payé en espèces, d'où partira la
/// commission (`GET /bids/{bidId}/commission-allocation`). Indicatif : le
/// prélèvement réel peut être inférieur (bon de réduction), jamais supérieur.
class CommissionAllocationPreview extends Equatable {
  const CommissionAllocationPreview({
    required this.bidCurrency,
    required this.commission,
    required this.covered,
    this.lines = const [],
    this.fundingDetail,
  });

  final String bidCurrency;
  final double commission;

  /// Les portefeuilles couvrent la commission ; sinon [lines] est vide et
  /// [fundingDetail] dit pourquoi.
  final bool covered;
  final List<CommissionAllocationLine> lines;
  final CommissionFundingDetail? fundingDetail;

  factory CommissionAllocationPreview.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    return CommissionAllocationPreview(
      bidCurrency: (json['bidCurrency'] as String).toUpperCase(),
      commission: (json['commission'] as num).toDouble(),
      covered: json['covered'] == true,
      lines: rawLines is List
          ? [
              for (final l in rawLines)
                if (l is Map)
                  CommissionAllocationLine.fromJson(
                    Map<String, dynamic>.from(l),
                  ),
            ]
          : const [],
      fundingDetail: CommissionFundingDetail.tryParse(json['fundingDetail']),
    );
  }

  /// Vrai quand le prélèvement ne se limite pas au portefeuille de la devise
  /// du colis : plusieurs portefeuilles, ou une conversion au taux du jour.
  /// Sinon rien à expliquer, l'acceptation part directement.
  bool get needsExplanation =>
      covered && (lines.length > 1 || lines.any((l) => l.converted));

  @override
  List<Object?> get props => [
    bidCurrency,
    commission,
    covered,
    lines,
    fundingDetail,
  ];
}
