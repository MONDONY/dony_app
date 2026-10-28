import 'package:equatable/equatable.dart';

/// Un portefeuille utilisable pour régler une commission : son solde dans sa
/// devise et ce qu'il règlerait dans la devise du colis (arrondi vers le bas).
class CommissionWalletShare extends Equatable {
  const CommissionWalletShare({
    required this.currency,
    required this.balance,
    required this.valueInBid,
  });

  final String currency;
  final double balance;
  final double valueInBid;

  factory CommissionWalletShare.fromJson(Map<String, dynamic> json) =>
      CommissionWalletShare(
        currency: (json['currency'] as String).toUpperCase(),
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        valueInBid: (json['valueInBid'] as num?)?.toDouble() ?? 0,
      );

  @override
  List<Object?> get props => [currency, balance, valueInBid];
}

/// Détail d'un « solde insuffisant » toutes devises confondues : ce que chaque
/// portefeuille utilisable règlerait dans la devise du colis, le total, ce qui
/// manque encore, et les portefeuilles écartés avec leur motif. Un « solde
/// insuffisant » signifie que la SOMME de tous les portefeuilles utilisables ne
/// couvre pas la commission. Absent avec un ancien back.
class CommissionFundingDetail extends Equatable {
  const CommissionFundingDetail({
    required this.bidCurrency,
    required this.commission,
    required this.availableInBid,
    required this.shortfallInBid,
    this.wallets = const [],
    this.excluded = const {},
  });

  /// Devise du colis, dans laquelle sont exprimés tous les montants ci-dessous.
  final String bidCurrency;
  final double commission;

  /// Ce que tous les portefeuilles utilisables règleraient ensemble.
  final double availableInBid;

  /// Ce qui manque encore (zéro quand la commission est couverte).
  final double shortfallInBid;
  final List<CommissionWalletShare> wallets;

  /// Portefeuilles écartés : devise → motif (`frozen`, `rate-stale`,
  /// `rate-missing`).
  final Map<String, String> excluded;

  static const frozen = 'frozen';
  static const rateStale = 'rate-stale';
  static const rateMissing = 'rate-missing';

  /// Lit le détail d'un corps de réponse ou d'une extension d'erreur ; `null`
  /// si absent ou mal formé (ancien back : l'écran retombe sur `breakdown`).
  static CommissionFundingDetail? tryParse(Object? raw) {
    if (raw is! Map) return null;
    try {
      return CommissionFundingDetail.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  factory CommissionFundingDetail.fromJson(Map<String, dynamic> json) {
    final rawWallets = json['wallets'];
    final rawExcluded = json['excluded'];
    return CommissionFundingDetail(
      bidCurrency: (json['bidCurrency'] as String).toUpperCase(),
      commission: (json['commission'] as num).toDouble(),
      availableInBid: (json['availableInBid'] as num?)?.toDouble() ?? 0,
      shortfallInBid: (json['shortfallInBid'] as num?)?.toDouble() ?? 0,
      wallets: rawWallets is List
          ? [
              for (final w in rawWallets)
                if (w is Map)
                  CommissionWalletShare.fromJson(Map<String, dynamic>.from(w)),
            ]
          : const [],
      excluded: rawExcluded is Map
          ? {
              for (final e in rawExcluded.entries)
                e.key.toString().toUpperCase(): e.value.toString(),
            }
          : const {},
    );
  }

  /// Au moins un portefeuille a été écarté (gelé ou taux à mettre à jour).
  bool get hasExclusions => excluded.isNotEmpty;

  @override
  List<Object?> get props => [
    bidCurrency,
    commission,
    availableInBid,
    shortfallInBid,
    wallets,
    excluded,
  ];
}
